import { GROUP_PADDING, absolutePosition, byId, descendants, groupHeaderHeight, isCluster, sizeOf, type AppNode } from './model'
import type { CardSize } from './cardSize'

/** How far past a group's edge, in screen pixels, dragged work goes before it pops out. Stickers use the same distance. */
export const POP_DISTANCE = 90

type Box = { x: number; y: number; width: number; height: number }

/**
 * Where dragged work belongs while it moves. `from` is the group it started in, and `home` is the group it has
 * popped out to, or undefined at the top level. `walls` is the home's box when the drag started.
 */
export type Escape = { roots: string[]; from: string | undefined; home: string | undefined; walls: Box | null }

const boxOf = (node: AppNode, nodeMap: Map<string, AppNode>, cardSize: CardSize): Box => ({
  ...absolutePosition(node, nodeMap),
  ...sizeOf(node, cardSize),
})

function boundsOf(boxes: Box[]): Box {
  const x = Math.min(...boxes.map((box) => box.x))
  const y = Math.min(...boxes.map((box) => box.y))

  return {
    x,
    y,
    width: Math.max(...boxes.map((box) => box.x + box.width)) - x,
    height: Math.max(...boxes.map((box) => box.y + box.height)) - y,
  }
}

/** How far a box sticks out past the walls, corner to corner. */
function overshoot(box: Box, walls: Box): number {
  const outX = Math.max(walls.x - box.x, box.x + box.width - (walls.x + walls.width), 0)
  const outY = Math.max(walls.y - box.y, box.y + box.height - (walls.y + walls.height), 0)

  return Math.hypot(outX, outY)
}

/** How far a point sits inside a box from its nearest edge, negative when outside. */
const depthInside = (point: { x: number; y: number }, box: Box) =>
  Math.min(point.x - box.x, box.x + box.width - point.x, point.y - box.y, box.y + box.height - point.y)

/** The dragged nodes whose parents aren't dragged too. They move as one block. */
export function dragRoots(nodes: AppNode[], ids: Iterable<string>): string[] {
  const dragged = new Set(ids)
  const nodeMap = byId(nodes)

  return [...dragged].filter((id) => {
    for (let parent = nodeMap.get(id)?.parentId; parent; parent = nodeMap.get(parent)?.parentId) if (dragged.has(parent)) return false

    return true
  })
}

/** Starts tracking a drag. Work from more than one group can't leave, since there's no single wall to pop through. */
export function startEscape(nodes: AppNode[], ids: Iterable<string>, cardSize: CardSize): Escape | null {
  const nodeMap = byId(nodes)
  const roots = dragRoots(nodes, ids).filter((id) => nodeMap.has(id))
  const parents = new Set(roots.map((id) => nodeMap.get(id)!.parentId))

  if (!roots.length || parents.size !== 1) return null

  const from = [...parents][0]
  const parent = from ? nodeMap.get(from) : undefined

  return { roots, from, home: from, walls: parent ? boxOf(parent, nodeMap, cardSize) : null }
}

/**
 * Follows a drag. Groups keep their size while work inside them is dragged. Once the dragged block sticks out more
 * than `pop` past its home's walls, it pops out to the next level, and leaving several levels in one sweep pops
 * through each. `before` is the canvas when the drag started.
 */
export function followEscape(nodes: AppNode[], escape: Escape, before: AppNode[], pop: number, cardSize: CardSize): Escape {
  if (!escape.walls) return escape

  const nodeMap = byId(nodes)
  const block = boundsOf(escape.roots.flatMap((id) => (nodeMap.has(id) ? [boxOf(nodeMap.get(id)!, nodeMap, cardSize)] : [])))
  const startMap = byId(before)
  let next = escape

  while (next.walls && overshoot(block, next.walls) > pop) {
    const left = next.home ? startMap.get(next.home) : undefined
    const home = left?.parentId
    const homeNode = home ? startMap.get(home) : undefined

    next = { ...next, home, walls: homeNode ? boxOf(homeNode, startMap, cardSize) : null }
  }

  return next
}

/**
 * Moves dropped work that stayed in its group back within the group's bounds, so dropping it short of the pop
 * distance never grows the group. Work dropped together in one group moves as one block, keeping its formation.
 */
export function landInside(nodes: AppNode[], ids: Iterable<string>, cardSize: CardSize): AppNode[] {
  const nodeMap = byId(nodes)
  const blocks = new Map<string, Box[]>()
  const roots = dragRoots(nodes, ids)

  for (const id of roots) {
    const node = nodeMap.get(id)

    if (!node?.parentId || !nodeMap.has(node.parentId)) continue

    blocks.set(node.parentId, [...(blocks.get(node.parentId) ?? []), { ...node.position, ...sizeOf(node, cardSize) }])
  }

  const shifts = new Map<string, { x: number; y: number }>()

  for (const [groupId, boxes] of blocks) {
    const group = nodeMap.get(groupId)!
    const size = sizeOf(group, cardSize)
    const block = boundsOf(boxes)
    const top = groupHeaderHeight(isCluster(group) ? group.data : undefined)
    // A block too big for the group keeps to its top left corner.
    const x = Math.max(GROUP_PADDING, Math.min(block.x, size.width - GROUP_PADDING - block.width))
    const y = Math.max(top, Math.min(block.y, size.height - GROUP_PADDING - block.height))

    if (x !== block.x || y !== block.y) shifts.set(groupId, { x: x - block.x, y: y - block.y })
  }

  if (!shifts.size) return nodes

  const moving = new Set(roots)

  return nodes.map((node) => {
    const shift = moving.has(node.id) && node.parentId ? shifts.get(node.parentId) : undefined

    return shift ? { ...node, position: { x: node.position.x + shift.x, y: node.position.y + shift.y } } : node
  })
}

/**
 * The group dragged work would land in if dropped now: the innermost group within its home that the block's center
 * is over, or else the home itself. The dragged work and everything inside it are never targets.
 */
export function dropTarget(nodes: AppNode[], escape: Escape, cardSize: CardSize): string | undefined {
  const nodeMap = byId(nodes)
  const block = boundsOf(escape.roots.flatMap((id) => (nodeMap.has(id) ? [boxOf(nodeMap.get(id)!, nodeMap, cardSize)] : [])))
  const center = { x: block.x + block.width / 2, y: block.y + block.height / 2 }
  const excluded = new Set(escape.roots.flatMap((id) => [id, ...descendants(id, nodes)]))
  let target = escape.home

  for (;;) {
    const inside = nodes.find(
      (node) => isCluster(node) && node.parentId === target && !excluded.has(node.id) && depthInside(center, boxOf(node, nodeMap, cardSize)) >= 0,
    )

    if (!inside) return target

    target = inside.id
  }
}

/**
 * Moves dragged work into another group, or to the top level, where it is on screen. An automatic group it joins or
 * leaves is marked to lay itself out again, as the CLI's move does. Returns the same nodes when the target is where
 * the work already is.
 */
export function reparent(nodes: AppNode[], roots: string[], target: string | undefined, from: string | undefined): AppNode[] {
  if (target === from) return nodes

  const nodeMap = byId(nodes)
  const origin = target && nodeMap.has(target) ? absolutePosition(nodeMap.get(target)!, nodeMap) : { x: 0, y: 0 }
  const moving = new Set(roots)

  return nodes.map((node) => {
    if (moving.has(node.id)) {
      const absolute = absolutePosition(node, nodeMap)

      return { ...node, parentId: target, position: { x: absolute.x - origin.x, y: absolute.y - origin.y } }
    }

    if ((node.id === target || node.id === from) && isCluster(node) && node.data.arrange !== 'custom' && !node.data.layout)
      return { ...node, data: { ...node.data, layout: 'refit' } }

    return node
  })
}
