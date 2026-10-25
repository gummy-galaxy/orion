import { TASK_HEIGHT, TASK_WIDTH } from '../geometry'
import { expect, test } from 'vitest'
import { byId, isCluster, normalize } from '../model'
import { cluster } from './fixtures/cluster'
import { task } from './fixtures/task'
import { groupEdgeAt } from './groupEdgeAt'

const size = { width: TASK_WIDTH, height: TASK_HEIGHT }

/** `outer` at the origin holding `inner`, which holds one card. */
const canvas = () => normalize([cluster('outer', undefined, 0, 0), cluster('inner', 'outer', 32, 78), task('card', 'inner', 32, 78)])

const groupEdge = (point: { x: number; y: number }) => {
  const nodes = canvas()

  return groupEdgeAt(byId(nodes), nodes.filter(isCluster), point, 8, size)
}

test('finds the group whose edge is near, on either side of it', () => {
  expect(groupEdge({ x: -5, y: 40 })).toBe('outer')
  expect(groupEdge({ x: 5, y: 40 })).toBe('outer')
})

test('picks the inner group near its own edge', () => {
  expect(groupEdge({ x: 34, y: 120 })).toBe('inner')
})

test('finds nothing far from every edge', () => {
  expect(groupEdge({ x: 100, y: 200 })).toBeNull()
  expect(groupEdge({ x: -100, y: 40 })).toBeNull()
})
