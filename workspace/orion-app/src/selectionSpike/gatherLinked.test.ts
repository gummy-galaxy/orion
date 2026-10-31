import { expect, test } from 'vitest'
import { gatherLinked } from './gatherLinked'

const links = [
  { from: 'a', to: 'b' },
  { from: 'b', to: 'c' },
  { from: 'a', to: 'd' },
  { from: 'd', to: 'e' },
]

test('gathers the origin and cards within the given hops, both ways along links', () => {
  expect([...gatherLinked(links, ['b'], 1)].sort()).toEqual(['a', 'b', 'c'])
  expect([...gatherLinked(links, ['b'], 2)].sort()).toEqual(['a', 'b', 'c', 'd'])
  expect([...gatherLinked(links, ['b'], 0)]).toEqual(['b'])
})

test('leaving a card behind also leaves what is only reached through it', () => {
  expect([...gatherLinked(links, ['a'], 3, new Set(['d']))].sort()).toEqual(['a', 'b', 'c'])
})
