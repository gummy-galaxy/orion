import { expect, test } from 'vitest'
import { ancestors, byId } from '../model'
import { node } from './fixtures/node'
import { indexNodes } from './indexNodes'

const nodes = [
  node('outer', undefined, 'cluster'),
  node('b', 'inner'),
  node('inner', 'outer', 'cluster'),
  node('a', 'inner'),
  node('loose'),
  node('c', 'outer'),
]

test('lists each parent’s direct children in node order', () => {
  const { children } = indexNodes(nodes)

  expect(children.get('outer')?.map((child) => child.id)).toEqual(['inner', 'c'])
  expect(children.get('inner')?.map((child) => child.id)).toEqual(['b', 'a'])
})

test('has no entry for a node with nothing inside', () => {
  const { children } = indexNodes(nodes)

  expect(children.has('loose')).toBe(false)
  expect(children.has('a')).toBe(false)
})

test('counts the same depth as walking ancestors, even before a parent appears', () => {
  const { depth } = indexNodes(nodes)
  const nodeMap = byId(nodes)

  for (const each of nodes) expect(depth.get(each.id)).toBe(ancestors(each.id, nodeMap).length)

  expect(depth.get('b')).toBe(2)
})

test('counts a parent id with no node behind it as a level', () => {
  expect(indexNodes([node('orphan', 'gone')]).depth.get('orphan')).toBe(1)
})

test('looks nodes up by id', () => {
  expect(indexNodes(nodes).byId.get('c')).toBe(nodes[5])
})
