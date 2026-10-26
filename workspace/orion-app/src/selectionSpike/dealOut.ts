import { CARD_HEIGHT, CARD_WIDTH } from './board'
import { cardRect } from './cardRect'
import { rectsOverlap } from './rectsOverlap'
import type { Point, Positions } from './types'

/** Space kept between a dealt card and anything else. */
export const DEAL_GAP = 28

/**
 * Deals `moving` cards into open slots on a grid that starts at `anchor`, nearest slot first,
 * so they spread out where they are and no settled card has to move to make room.
 */
export function dealOut(positions: Positions, moving: string[], anchor: Point): Positions {
  const settled = Object.keys(positions)
    .filter((id) => !moving.includes(id))
    .map((id) => cardRect(positions[id]))
  const stepX = CARD_WIDTH + DEAL_GAP
  const stepY = CARD_HEIGHT + DEAL_GAP
  const slots: (Point & { distance: number })[] = []

  // Only rows at or below the anchor, so the pile spreads down and sideways, never up past where it sat.
  for (let row = 0; row <= 6; row++) {
    for (let column = -8; column <= 8; column++) {
      const slot = { x: anchor.x + column * stepX, y: anchor.y + row * stepY }

      // Rows weigh more than columns, so the pile reads as a line before it grows a block.
      slots.push({ ...slot, distance: Math.hypot(column, row * 1.6) })
    }
  }

  slots.sort((a, b) => a.distance - b.distance)

  const taken = [...settled]
  const result: Positions = {}

  for (const id of moving) {
    const slot = slots.find((candidate) => !taken.some((rect) => rectsOverlap(cardRect(candidate), rect, DEAL_GAP - 1)))

    if (!slot) continue

    result[id] = { x: slot.x, y: slot.y }
    taken.push(cardRect(slot))
  }

  return result
}
