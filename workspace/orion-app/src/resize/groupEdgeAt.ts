import { absolutePosition, sizeOf, type AppNode } from '../model'
import type { CardSize } from '../cardSize'
import type { Point } from './types'

/**
 * The group among `groups` whose border runs within `reach` of `point`, in canvas coordinates, or null. When borders
 * of several are that close, the nearest wins, and a group inside another wins a tie. `nodeMap` places them.
 */
export function groupEdgeAt(
  nodeMap: Map<string, AppNode>,
  groups: AppNode[],
  point: Point,
  reach: number,
  cardSize: CardSize,
): string | null {
  let best: { id: string; distance: number } | null = null

  for (const group of groups) {
    const { x, y } = absolutePosition(group, nodeMap)
    const { width, height } = sizeOf(group, cardSize)
    const outside = Math.max(x - point.x, point.x - (x + width), y - point.y, point.y - (y + height))
    const inside = Math.min(point.x - x, x + width - point.x, point.y - y, y + height - point.y)
    const distance = outside > 0 ? outside : inside

    if (distance > reach || (best && distance > best.distance)) continue

    best = { id: group.id, distance }
  }

  return best?.id ?? null
}
