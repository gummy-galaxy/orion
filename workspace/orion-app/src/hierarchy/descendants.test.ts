import { expect, test } from 'vitest'
import { node } from './fixtures/node'
import { descendants } from './descendants'
import { indexNodes } from './indexNodes'

const nodes = [
  node('outer', undefined, 'cluster'),
  node('inner', 'outer', 'cluster'),
  node('c', 'outer'),
  node('b', 'inner'),
  node('loose'),
]

test('gathers everything inside at any depth, each node before what it holds', () => {
  expect([...descendants('outer', indexNodes(nodes).children)]).toEqual(['inner', 'b', 'c'])
})

test('is empty for a node with nothing inside', () => {
  expect(descendants('loose', indexNodes(nodes).children).size).toBe(0)
})

test('stops at a parent loop', () => {
  const a = node('a', 'b')
  const b = node('b', 'a')

  expect([
    ...descendants(
      'a',
      new Map([
        ['a', [b]],
        ['b', [a]],
      ]),
    ),
  ]).toEqual(['b', 'a'])
})
