import { isCluster, sizeOf, type AppNode } from './model'

export type GroupPosition = { x: number; y: number }

/** Pack top-level groups left until each touches the wall or another group. */
export function settleGroups(nodes: AppNode[], positions: ReadonlyMap<string, GroupPosition>, movedId?: string): Map<string, GroupPosition> {
  const groups = nodes.filter((node) => isCluster(node) && !node.parentId)
  if (!groups.length) return new Map()
  const wall = Math.min(...groups.map((group) => group.position.x))
  const candidates = groups.map((group) => {
    const size = sizeOf(group)
    return { id: group.id, position: positions.get(group.id) ?? group.position, width: size.w, height: size.h }
  })
  // A group dropped onto another is placed after its support. Dragging well to the
  // left of a group still lets it become the new foundation.
  candidates.sort((a, b) => {
    const ax = a.position.x + (a.id === movedId ? Math.min(a.width / 4, 80) : 0)
    const bx = b.position.x + (b.id === movedId ? Math.min(b.width / 4, 80) : 0)
    return ax - bx || a.position.y - b.position.y || a.id.localeCompare(b.id)
  })

  const placed: { x: number; y: number; width: number; height: number }[] = []
  const settled = new Map<string, GroupPosition>()
  for (const group of candidates) {
    let x = wall
    for (const support of placed) {
      const overlapsVertically = group.position.y < support.y + support.height && support.y < group.position.y + group.height
      if (overlapsVertically) x = Math.max(x, support.x + support.width)
    }
    placed.push({ x, y: group.position.y, width: group.width, height: group.height })
    settled.set(group.id, { x, y: group.position.y })
  }
  return settled
}
