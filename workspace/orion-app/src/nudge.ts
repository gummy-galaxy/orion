import { shift } from './snap'
import { isCluster, byId, ancestors, type AppNode } from './model'
import { normalizeChord, type ShortcutId } from './keybindings'

/** One press of an arrow key moves the selection this many canvas units. */
export const NUDGE_STEP = 1
/** Holding ⇧ with an arrow key moves the selection this many canvas units. */
export const NUDGE_LARGE_STEP = 10

export const NUDGES: readonly { id: ShortcutId; x: number; y: number }[] = [
  { id: 'nudge-up', x: 0, y: -1 },
  { id: 'nudge-down', x: 0, y: 1 },
  { id: 'nudge-left', x: -1, y: 0 },
  { id: 'nudge-right', x: 1, y: 0 },
]

/** The chord that makes a nudge large: the same key with ⇧ added. */
export function largeChordOf(chord: string): string {
  return chord ? normalizeChord(`Shift+${chord}`) : ''
}

/**
 * The selected nodes a nudge can move. A node inside a selected group moves with that group, and
 * a child of an automatic group keeps its place, since the group lays it out, as a drag does.
 */
export function nudgeIds(nodes: AppNode[], ids: string[]): string[] {
  const nodeMap = byId(nodes)
  const selected = new Set(ids)

  return ids.filter((id) => {
    const node = nodeMap.get(id)

    if (!node) return false

    if (ancestors(id, nodeMap).some((ancestor) => selected.has(ancestor))) return false

    const parent = node.parentId ? nodeMap.get(node.parentId) : undefined

    return !(parent && isCluster(parent) && parent.data.arrange !== 'custom')
  })
}

/** Moves the selected nodes by a delta in canvas units. Returns the same array when nothing can move. */
export function nudgeNodes(nodes: AppNode[], ids: string[], deltaX: number, deltaY: number): AppNode[] {
  const movable = nudgeIds(nodes, ids)

  if (!movable.length || (!deltaX && !deltaY)) return nodes

  return shift(nodes, movable, deltaX, deltaY)
}
