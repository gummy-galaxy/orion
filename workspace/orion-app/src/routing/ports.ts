import type { Box, Point } from './types'

/** Links leave a card from the middle of its right side, where React Flow puts the source handle. */
export function sourcePort(card: Box): Point {
  return { x: card.x + card.width, y: card.y + card.height / 2 }
}

/** Links arrive in the middle of a card's left side, where the target handle sits. */
export function targetPort(card: Box): Point {
  return { x: card.x, y: card.y + card.height / 2 }
}
