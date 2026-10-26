import { expect, test } from 'vitest'
import { card } from './fixtures/card'
import { isSameTableNodes } from './isSameTableNodes'

const nodes = [card('a', 'First'), card('b', 'Second')]

test('ignores moving and selecting a card', () => {
  const moved = nodes.map((node) => ({ ...node, position: { x: 40, y: 80 }, selected: true, dragging: true }))

  expect(isSameTableNodes(nodes, moved)).toBe(true)
})

test("notices a card's data changing", () => {
  expect(isSameTableNodes(nodes, [nodes[0], { ...nodes[1], data: { ...nodes[1].data, label: 'Renamed' } }])).toBe(false)
})

test('notices a card moving into a group', () => {
  expect(isSameTableNodes(nodes, [nodes[0], { ...nodes[1], parentId: 'group' }])).toBe(false)
})

test('notices a card added or removed', () => {
  expect(isSameTableNodes(nodes, nodes.slice(0, 1))).toBe(false)
  expect(isSameTableNodes(nodes, [...nodes, card('c', 'Third')])).toBe(false)
})
