import { expect, test } from 'vitest'
import { cardsInCircle } from './cardsInCircle'

test('picks a card when any part of it is within reach', () => {
  const positions = { near: { x: 0, y: 0 }, far: { x: 1000, y: 0 } }

  // The near card's right edge is at 198, so a point 50 past it is in reach at 60 but not 40.
  expect(cardsInCircle(positions, { x: 248, y: 100 }, 60)).toEqual(['near'])
  expect(cardsInCircle(positions, { x: 248, y: 100 }, 40)).toEqual([])
})
