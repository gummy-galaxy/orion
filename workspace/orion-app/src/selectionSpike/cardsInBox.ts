import { covers, MARQUEE_REACH } from '../marquee'
import { cardRect } from './cardRect'
import type { Positions, Rect } from './types'

/** The cards the canvas's selection box picks up today: a quarter of the card in each direction. */
export function cardsInBox(positions: Positions, box: Rect) {
  return Object.keys(positions).filter((id) => covers(cardRect(positions[id]), box, MARQUEE_REACH))
}
