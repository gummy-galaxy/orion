import { expect, test } from 'vitest'
import { planReflow } from '../layout'
import { GROUP_PADDING, TASK_HEIGHT, TASK_WIDTH, byId, normalize, type AppNode, type ClusterData } from '../model'
import { boxOf } from './fixtures/boxOf'
import { cluster } from './fixtures/cluster'
import { task } from './fixtures/task'
import { resizeAutoGroup } from './resizeAutoGroup'

const size = { width: TASK_WIDTH, height: TASK_HEIGHT }
/** Space between unlinked cards in a group's grid. */
const COMPONENT_GAP = 32

/** An automatic group at (100, 100) holding six unlinked cards in a row. */
const canvas = () =>
  normalize([
    cluster('g', undefined, 100, 100),
    ...Array.from({ length: 6 }, (_, i) => task(`t${i}`, 'g', 32 + i * (TASK_WIDTH + COMPONENT_GAP), 78)),
  ])

const columns = (nodes: AppNode[]) => new Set(nodes.filter((node) => node.parentId === 'g').map((node) => node.position.x)).size
const rows = (nodes: AppNode[]) => new Set(nodes.filter((node) => node.parentId === 'g').map((node) => node.position.y)).size

const widthFor = (count: number) => count * TASK_WIDTH + (count - 1) * COMPONENT_GAP + GROUP_PADDING * 2

test('reflows to the width a side edge asks for, and hugs the result', async () => {
  const before = canvas()
  const start = boxOf(before, 'g')
  const plan = (await planReflow(before, [], 'g', size))!
  const after = resizeAutoGroup(plan, 'g', start, { ...start, width: widthFor(3) + 40 }, { right: true }, size)

  expect(columns(after)).toBe(3)
  expect(boxOf(after, 'g')).toMatchObject({ x: 100, y: 100, width: widthFor(3) })
  expect((byId(after).get('g')!.data as ClusterData).size).toEqual({ width: widthFor(3), height: boxOf(after, 'g').height })
})

test('holds the right edge while the left edge moves', async () => {
  const before = canvas()
  const start = boxOf(before, 'g')
  const plan = (await planReflow(before, [], 'g', size))!
  const box = { ...start, x: start.x + start.width - widthFor(2), width: widthFor(2) }
  const after = resizeAutoGroup(plan, 'g', start, box, { left: true }, size)

  expect(boxOf(after, 'g').x + boxOf(after, 'g').width).toBe(start.x + start.width)
})

test('picks the layout closest to the height a bottom edge asks for, changing the width least', async () => {
  const before = canvas()
  const start = boxOf(before, 'g')
  const plan = (await planReflow(before, [], 'g', size))!
  const twoRows = plan.measure(widthFor(3) - GROUP_PADDING * 2).height
  const after = resizeAutoGroup(plan, 'g', start, { ...start, height: twoRows + 10 }, { bottom: true }, size)

  expect(rows(after)).toBe(2)
  expect(columns(after)).toBe(5)
})
