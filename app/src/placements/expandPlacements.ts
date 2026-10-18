import { isTask, type AppNode } from '../model'
import type { Placement } from './types'

/** The nodes the canvas draws: every stored node, then a copy of a card for each of its extra placements. */
export function expandPlacements(nodes: AppNode[], placements: Placement[] | undefined): AppNode[] {
  if (!placements?.length) return nodes

  const cards = new Map(nodes.filter(isTask).map((node) => [node.id, node]))
  const copies: AppNode[] = []

  for (const placement of placements) {
    const card = cards.get(placement.node)

    if (!card) continue

    const { parentId: _parentId, ...rest } = card

    copies.push({
      ...rest,
      id: placement.id,
      position: placement.position,
      ...(placement.parentId ? { parentId: placement.parentId } : {}),
      selected: false,
      data: { ...card.data, copyOf: card.id },
    })
  }

  return [...nodes, ...copies]
}
