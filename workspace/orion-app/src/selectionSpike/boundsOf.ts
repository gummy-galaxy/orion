import { cardRect } from './cardRect'
import type { Positions, Rect } from './types'

/** The rectangle around every card in `ids`. */
export function boundsOf(positions: Positions, ids: Iterable<string>): Rect | null {
  let bounds: Rect | null = null

  for (const id of ids) {
    const rect = cardRect(positions[id])

    bounds = bounds
      ? { x0: Math.min(bounds.x0, rect.x0), y0: Math.min(bounds.y0, rect.y0), x1: Math.max(bounds.x1, rect.x1), y1: Math.max(bounds.y1, rect.y1) }
      : rect
  }

  return bounds
}
