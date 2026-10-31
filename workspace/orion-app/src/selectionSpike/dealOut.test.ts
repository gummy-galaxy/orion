import { expect, test } from 'vitest'
import { CARDS } from './board'
import { cardRect } from './cardRect'
import { dealOut } from './dealOut'
import { rectsOverlap } from './rectsOverlap'

test('deals the pile into open slots that overlap nothing', () => {
  const positions = Object.fromEntries(CARDS.map((card) => [card.id, { x: card.x, y: card.y }]))
  const pile = CARDS.filter((card) => card.area === 'new').map((card) => card.id)
  const dealt = dealOut(positions, pile, positions[pile[0]])
  const after = { ...positions, ...dealt }

  expect(Object.keys(dealt)).toEqual(pile)

  for (const id of pile) {
    for (const other of Object.keys(after)) {
      if (other !== id) expect(rectsOverlap(cardRect(after[id]), cardRect(after[other]))).toBe(false)
    }
  }
})
