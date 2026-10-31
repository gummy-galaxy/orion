import { closesOut } from './celebrate'
import { diffCardFields } from './fields/diffCardFields'
import type { Link, TaskData } from './model'
import { stableJson } from './stableJson'

/** One edit the server applies, in the shape `POST /api/operations` reads. */
export type Operation = { op: string } & Record<string, unknown>

/** A node as the server keeps it: the stored form, without the view's selection or measurements. */
export type StoredNode = {
  id: string
  type: string
  position: { x: number; y: number }
  parentId?: string
  data: object
  width?: number
  height?: number
}

/** A document in the stored form the operations compare. */
export type OperationDoc = { nodes: StoredNode[]; links: Link[]; stickers?: unknown[]; stickerLoadout?: unknown[] }

const isGroup = (node: StoredNode) => node.type === 'cluster'
const keyOf = (from: string, to: string) => `${from}\0${to}`

const sameJson = (a: unknown, b: unknown) => stableJson(a) === stableJson(b)

function moveOp(node: StoredNode): Operation {
  return node.parentId ? { op: 'move', id: node.id, group: node.parentId } : { op: 'move', id: node.id }
}

/**
 * The add operation for a new node. Ids and positions are the canvas's; the server only checks they're free and sit in
 * a group.
 */
function addOp(node: StoredNode): Operation {
  const fields = {
    id: node.id,
    x: node.position.x,
    y: node.position.y,
    group: node.parentId,
    width: node.width,
    height: node.height,
    data: node.data,
  }

  if (node.type === 'cluster') return { op: 'addGroup', ...fields }

  if (node.type === 'image') return { op: 'addImage', ...fields }

  return { op: (node.data as TaskData).type === 'note' ? 'addNote' : 'addCard', ...fields }
}

/**
 * The edits that turn `base` into `current`, in the order the server can apply them. Both documents are in the stored
 * form. Membership goes through `group`, `ungroup`, and `move`, which the server checks; everything else is the
 * field, size, and position the canvas holds.
 */
export function diffOperations(base: OperationDoc, current: OperationDoc): Operation[] {
  const before = new Map(base.nodes.map((node) => [node.id, node]))
  const after = new Map(current.nodes.map((node) => [node.id, node]))
  const operations: Operation[] = []

  // How many groups a node sits inside, so new items are created after the groups they go in.
  const depth = (id: string) => {
    let count = 0
    let parent = after.get(id)?.parentId

    while (parent && after.has(parent) && count < 1000) {
      count++
      parent = after.get(parent)?.parentId
    }

    return count
  }

  const removed = base.nodes.filter((node) => !after.has(node.id))

  // A group that's gone but whose remaining items all moved up to its parent dissolves; the server hands them up.
  const ungrouped: string[] = []
  const handled = new Set<string>()

  for (const group of removed.filter(isGroup)) {
    const children = base.nodes.filter((node) => node.parentId === group.id && after.has(node.id))

    if (children.length && children.every((child) => after.get(child.id)?.parentId === group.parentId)) {
      ungrouped.push(group.id)

      for (const child of children) handled.add(child.id)
    }
  }

  for (const id of ungrouped) operations.push({ op: 'ungroup', id })

  // New items, parents first. A new group takes the items already in it, after they share one parent.
  const grouped = new Set<string>()
  const created = current.nodes.filter((node) => !before.has(node.id)).sort((a, b) => depth(a.id) - depth(b.id))

  for (const node of created) {
    const members = isGroup(node)
      ? current.nodes.filter((item) => item.parentId === node.id && before.has(item.id))
      : []

    if (!members.length) {
      operations.push(addOp(node))
      continue
    }

    for (const member of members) {
      grouped.add(member.id)

      if (before.get(member.id)?.parentId !== node.parentId) {
        operations.push(
          node.parentId ? { op: 'move', id: member.id, group: node.parentId } : { op: 'move', id: member.id },
        )
      }
    }

    const label = (node.data as { label?: unknown }).label

    operations.push({
      op: 'group',
      id: node.id,
      label: typeof label === 'string' && label ? label : 'Group',
      items: members.map((member) => member.id),
    })
    // The server sets its own size and label for the group, so the canvas's values follow.
    operations.push({ op: 'setData', id: node.id, data: node.data })

    if (node.width !== undefined && node.height !== undefined)
      operations.push({ op: 'resize', id: node.id, width: node.width, height: node.height })

    operations.push({ op: 'place', id: node.id, x: node.position.x, y: node.position.y })
  }

  // Items that changed parent. Moving out of a group can empty it, and the server removes an empty group, so a move
  // that would empty a group another move still needs waits its turn.
  const childCount = new Map<string, number>()

  for (const node of base.nodes)
    if (node.parentId) childCount.set(node.parentId, (childCount.get(node.parentId) ?? 0) + 1)

  const pending = current.nodes.filter((node) => {
    const previous = before.get(node.id)

    return !!previous && !grouped.has(node.id) && !handled.has(node.id) && previous.parentId !== node.parentId
  })

  while (pending.length) {
    const needed = new Set(pending.map((node) => node.parentId).filter((parent): parent is string => !!parent))

    const leaving = (node: StoredNode) => {
      const from = before.get(node.id)?.parentId

      return !!from && childCount.get(from) === 1 && needed.has(from)
    }

    const index = Math.max(
      0,
      pending.findIndex((node) => !leaving(node)),
    )
    const [node] = pending.splice(index, 1)
    const from = before.get(node.id)?.parentId

    operations.push(moveOp(node))

    if (from) childCount.set(from, (childCount.get(from) ?? 0) - 1)

    if (node.parentId) childCount.set(node.parentId, (childCount.get(node.parentId) ?? 0) + 1)
  }

  // Edits to items that stay, once the groups they sit in are settled.
  const existing = current.nodes.filter((node) => before.has(node.id))

  for (const node of existing) {
    const previous = before.get(node.id)!

    if (sameJson(previous.data, node.data)) continue

    // Groups and images keep their data whole. Cards change through their fields, which the server checks.
    if (node.type !== 'task') {
      operations.push({ op: 'setData', id: node.id, data: node.data })
      continue
    }

    const previousData = previous.data as TaskData
    const data = node.data as TaskData
    const fields = diffCardFields(previousData, data)

    if (Object.keys(fields).length) operations.push({ op: 'setFields', id: node.id, fields })

    // Finishing a card in the app closes it out at once, so its Done stamp lands instead of waiting.
    if (closesOut(previousData, data)) operations.push({ op: 'closeOut', id: node.id })
  }

  for (const node of existing) {
    const previous = before.get(node.id)!

    if (previous.width === node.width && previous.height === node.height) continue

    if (node.width === undefined || node.height === undefined)
      operations.push({ op: 'resize', id: node.id, clear: true })
    else operations.push({ op: 'resize', id: node.id, width: node.width, height: node.height })
  }

  for (const node of existing) {
    const previous = before.get(node.id)!
    const moved = previous.position.x !== node.position.x || previous.position.y !== node.position.y

    if (moved || previous.parentId !== node.parentId)
      operations.push({ op: 'place', id: node.id, x: node.position.x, y: node.position.y })
  }

  const beforeLinks = new Map(base.links.map((link) => [keyOf(link.from, link.to), link]))
  const afterLinks = new Map(current.links.map((link) => [keyOf(link.from, link.to), link]))

  for (const [key, link] of beforeLinks) {
    if (!afterLinks.has(key) && after.has(link.from) && after.has(link.to))
      operations.push({ op: 'unlink', from: link.from, to: link.to })
  }

  for (const [key, link] of afterLinks) {
    const previous = beforeLinks.get(key)

    const relabeled = (previous?.label ?? '') !== (link.label ?? '')

    if ((!previous || previous.kind !== link.kind || relabeled) && after.has(link.from) && after.has(link.to)) {
      // An empty label clears one the link had.
      operations.push({
        op: 'link',
        from: link.from,
        to: link.to,
        kind: link.kind,
        ...(link.label || relabeled ? { label: link.label ?? '' } : {}),
      })
    }
  }

  // Removals come last, so no group empties while a move still needs it. The server removes a group once it's empty.
  for (const node of removed.filter((node) => !isGroup(node))) operations.push({ op: 'remove', id: node.id })

  for (const group of removed.filter(isGroup)) {
    if (ungrouped.includes(group.id)) continue

    if (!base.nodes.some((node) => node.parentId === group.id)) operations.push({ op: 'removeGroup', id: group.id })
  }

  if (!sameJson(base.stickers ?? [], current.stickers ?? []))
    operations.push({ op: 'setStickers', stickers: current.stickers ?? [] })

  if (!sameJson(base.stickerLoadout ?? [], current.stickerLoadout ?? [])) {
    operations.push({ op: 'setStickerLoadout', stickerLoadout: current.stickerLoadout ?? [] })
  }

  return operations
}
