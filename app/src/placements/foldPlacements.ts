import type { Placement } from './types'

type Folding = { id: string; parentId?: string; position: { x: number; y: number }; data: object }

/**
 * Splits the canvas's nodes back into stored nodes and placements: each copy of a card becomes a placement, and the
 * card's own node keeps its data. Placements sort by id so the stored form doesn't depend on drawing order.
 */
export function foldPlacements<T extends Folding>(nodes: T[]): { nodes: T[]; placements: Placement[] } {
  const kept: T[] = []
  const placements: Placement[] = []

  for (const node of nodes) {
    const copyOf = (node.data as { copyOf?: unknown }).copyOf

    if (typeof copyOf !== 'string') {
      kept.push(node)
      continue
    }

    placements.push({ id: node.id, node: copyOf, ...(node.parentId ? { parentId: node.parentId } : {}), position: node.position })
  }

  placements.sort((a, b) => a.id.localeCompare(b.id))

  return { nodes: kept, placements }
}
