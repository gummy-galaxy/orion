import { CARD_HEIGHT, CARD_WIDTH } from './board'
import type { Point, Rect } from './types'

export function cardRect(position: Point): Rect {
  return { x0: position.x, y0: position.y, x1: position.x + CARD_WIDTH, y1: position.y + CARD_HEIGHT }
}
