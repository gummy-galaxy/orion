import { GAP, GROUP_HEADER_HEIGHT, GROUP_PADDING, TASK_HEIGHT, TASK_WIDTH } from '../geometry'
import { expect, test } from 'vitest'
import { byId, normalize, type ClusterData } from '../model'
import { boxOf } from './fixtures/boxOf'
import { cluster } from './fixtures/cluster'
import { task } from './fixtures/task'
import { resizeCustomGroup } from './resizeCustomGroup'

const size = { width: TASK_WIDTH, height: TASK_HEIGHT }

/** A custom group at (100, 100) with two cards side by side, `b` 200 to the right of `a`, and a card beside it. */
const canvas = () =>
  normalize([
    cluster('g', undefined, 100, 100, { arrange: 'custom' }),
    task('a', 'g', 32, 78),
    task('b', 'g', 32 + TASK_WIDTH + 200, 78),
    task('outside', undefined, 2000, 100),
  ])

test('grows past its contents and keeps the room', () => {
  const before = canvas()
  const start = boxOf(before, 'g')
  const after = resizeCustomGroup(before, 'g', { ...start, width: start.width + 300, height: start.height + 100 }, size)

  expect(boxOf(after, 'g')).toEqual({ ...start, width: start.width + 300, height: start.height + 100 })
  expect((byId(after).get('g')!.data as ClusterData).size).toEqual({
    width: start.width + 300,
    height: start.height + 100,
  })
  expect(byId(after).get('b')!.position).toEqual(byId(before).get('b')!.position)
})

test('grows to the left and up while its contents stay where they are on screen', () => {
  const before = canvas()
  const start = boxOf(before, 'g')
  const after = resizeCustomGroup(
    before,
    'g',
    { x: start.x - 100, y: start.y - 50, width: start.width + 100, height: start.height + 50 },
    size,
  )

  expect(boxOf(after, 'g')).toMatchObject({ x: start.x - 100, y: start.y - 50 })
  expect(byId(after).get('a')!.position).toEqual({ x: 132, y: 128 })
})

test('pushes the cards an edge moving in meets, keeping up to the standard gap', () => {
  const before = canvas()
  const start = boxOf(before, 'g')
  const after = resizeCustomGroup(before, 'g', { ...start, width: start.width - 100 }, size)
  const nodeMap = byId(after)

  expect(nodeMap.get('b')!.position.x).toBe(32 + TASK_WIDTH + 100)
  expect(nodeMap.get('a')!.position.x).toBe(32)
  expect(boxOf(after, 'g').width).toBe(start.width - 100)
})

test('stops the edge once the cards it pushed fill the group', () => {
  const before = canvas()
  const start = boxOf(before, 'g')
  const after = resizeCustomGroup(before, 'g', { ...start, width: 300 }, size)
  const nodeMap = byId(after)

  expect(nodeMap.get('a')!.position.x).toBe(GROUP_PADDING)
  expect(nodeMap.get('b')!.position.x).toBe(GROUP_PADDING + TASK_WIDTH + GAP.inner.x)
  expect(boxOf(after, 'g').width).toBe(2 * TASK_WIDTH + GAP.inner.x + 2 * GROUP_PADDING)
})

test('pushes cards down ahead of a top edge moving in, keeping them below the title', () => {
  const before = canvas()
  const start = boxOf(before, 'g')
  const after = resizeCustomGroup(before, 'g', { ...start, y: start.y + 40, height: start.height + 160 }, size)

  expect(boxOf(after, 'g').y).toBe(start.y + 40)
  expect(byId(after).get('a')!.position.y).toBe(GROUP_HEADER_HEIGHT)
})

test('holds a top edge that has no room to push into', () => {
  const before = canvas()
  const start = boxOf(before, 'g')
  const after = resizeCustomGroup(before, 'g', { ...start, y: start.y + 40, height: start.height - 40 }, size)

  expect(boxOf(after, 'g')).toEqual(start)
})

test('leaves what is outside the group alone', () => {
  const before = canvas()
  const start = boxOf(before, 'g')
  const after = resizeCustomGroup(before, 'g', { ...start, width: start.width + 300 }, size)

  expect(byId(after).get('outside')!.position).toEqual(byId(before).get('outside')!.position)
})
