import type { CardSize } from './cardSize'
import { absolutePosition, ancestors, isCluster, isTask, sizeOf, type AppNode, type ViewStatus } from './model'

/** A miniature of something inside a folded group, placed in the group's own coordinates. */
export type FoldPreviewItem = {
  id: string
  kind: 'group' | 'card' | 'image'
  /** Set on cards, so they take the color of their status. */
  status: ViewStatus | null
  x: number
  y: number
  width: number
  height: number
  /** How many groups sit between this item and the folded group it shows in. */
  depth: number
}

/** Most items drawn per folded group, nearest first, so a big group stays cheap to draw. */
export const FOLD_PREVIEW_LIMIT = 80

/**
 * Works out what each folded group hints at: everything inside it, at any depth, with positions relative to the group.
 * Only the outermost folded group above an item gets it, since anything inside a folded group is hidden.
 */
export function foldPreviews(
  nodes: AppNode[],
  map: Map<string, AppNode>,
  folded: Set<string>,
  cardSize: CardSize,
  status: Map<string, ViewStatus>,
): Map<string, FoldPreviewItem[]> {
  const previews = new Map<string, FoldPreviewItem[]>()

  if (!folded.size) return previews

  const origins = new Map<string, { x: number; y: number }>()

  const originOf = (id: string) => {
    const known = origins.get(id)

    if (known) return known

    const node = map.get(id)
    const origin = node ? absolutePosition(node, map) : { x: 0, y: 0 }

    origins.set(id, origin)

    return origin
  }

  for (const node of nodes) {
    const chain = ancestors(node.id, map)
    const groupId = [...chain].reverse().find((ancestor) => folded.has(ancestor))

    if (!groupId) continue

    const origin = originOf(groupId)
    const at = absolutePosition(node, map)
    const size = sizeOf(node, cardSize)
    const kind: FoldPreviewItem['kind'] = isCluster(node) ? 'group' : isTask(node) ? 'card' : 'image'
    const item: FoldPreviewItem = {
      id: node.id,
      kind,
      status: kind === 'card' ? (status.get(node.id) ?? 'ready') : null,
      x: at.x - origin.x,
      y: at.y - origin.y,
      width: size.width,
      height: size.height,
      depth: chain.indexOf(groupId),
    }

    const list = previews.get(groupId)

    if (list) list.push(item)
    else previews.set(groupId, [item])
  }

  for (const [groupId, list] of previews) {
    previews.set(groupId, list.length > FOLD_PREVIEW_LIMIT ? list.sort((a, b) => a.depth - b.depth).slice(0, FOLD_PREVIEW_LIMIT) : list)
  }

  return previews
}

/** Whether two previews draw the same, so a folded group only redraws when its contents move. */
export function sameFoldPreview(a: FoldPreviewItem[] | undefined, b: FoldPreviewItem[] | undefined): boolean {
  if (a === b) return true

  if (!a || !b) return false

  return (
    a.length === b.length &&
    a.every((item, index) => {
      const other = b[index]

      return (
        item.id === other.id &&
        item.kind === other.kind &&
        item.status === other.status &&
        item.x === other.x &&
        item.y === other.y &&
        item.width === other.width &&
        item.height === other.height &&
        item.depth === other.depth
      )
    })
  )
}
