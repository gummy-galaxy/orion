import { cardRect } from './cardRect'
import type { Point, Positions } from './types'

/** The cards any part of which lies within `radius` of `center`. */
export function cardsInCircle(positions: Positions, center: Point, radius: number) {
  return Object.keys(positions).filter((id) => {
    const rect = cardRect(positions[id])
    const x = Math.max(rect.x0, Math.min(center.x, rect.x1))
    const y = Math.max(rect.y0, Math.min(center.y, rect.y1))

    return Math.hypot(center.x - x, center.y - y) <= radius
  })
}
