import { describe, expect, it } from 'vitest'
import { nudgeIds, nudgeNodes, NUDGE_LARGE_STEP, NUDGE_STEP } from './nudge'
import type { AppNode, ClusterNode } from './model'

const task = (id: string, x: number, y: number, parentId?: string): AppNode => ({
  id,
  type: 'task',
  parentId,
  position: { x, y },
  data: { kind: 'task', label: id, itemKind: 'step', status: 'todo' },
})

const group = (
  id: string,
  x: number,
  y: number,
  arrange: 'auto' | 'custom' = 'custom',
  parentId?: string,
): ClusterNode => ({
  id,
  type: 'cluster',
  parentId,
  position: { x, y },
  width: 400,
  height: 300,
  data: { kind: 'cluster', label: id, arrange },
})

describe('nudge math', () => {
  it('moves each selected card by the delta in canvas units', () => {
    const nodes = [task('a', 0, 0), task('b', 100, 50), task('c', 300, 300)]
    const moved = nudgeNodes(nodes, ['a', 'b'], NUDGE_STEP, 0)

    expect(moved.map((node) => node.position)).toEqual([
      { x: 1, y: 0 },
      { x: 101, y: 50 },
      { x: 300, y: 300 },
    ])
  })

  it('moves ten units for the large step, in either direction', () => {
    const nodes = [task('a', 50, 50)]

    expect(nudgeNodes(nodes, ['a'], 0, -NUDGE_LARGE_STEP)[0].position).toEqual({ x: 50, y: 40 })
    expect(nudgeNodes(nodes, ['a'], -NUDGE_LARGE_STEP, 0)[0].position).toEqual({ x: 40, y: 50 })
  })

  it('returns the same array when nothing is selected or the delta is zero', () => {
    const nodes = [task('a', 0, 0)]

    expect(nudgeNodes(nodes, [], 1, 0)).toBe(nodes)
    expect(nudgeNodes(nodes, ['a'], 0, 0)).toBe(nodes)
    expect(nudgeNodes(nodes, ['missing'], 1, 0)).toBe(nodes)
  })

  it('moves a selected group with its children, which keep their place inside it', () => {
    const nodes = [group('g', 100, 100), task('child', 20, 20, 'g')]
    const moved = nudgeNodes(nodes, ['g'], 5, 0)

    expect(moved[0].position).toEqual({ x: 105, y: 100 })
    expect(moved[1].position).toEqual({ x: 20, y: 20 })
  })

  it('moves a selected child only once when its selected group also moves', () => {
    const nodes = [group('g', 100, 100), task('child', 20, 20, 'g')]

    expect(nudgeIds(nodes, ['g', 'child'])).toEqual(['g'])
    expect(nudgeNodes(nodes, ['g', 'child'], 0, 4)[1].position).toEqual({ x: 20, y: 20 })
  })

  it('leaves children of an automatic group in place, as a drag does', () => {
    const nodes = [group('auto', 0, 0, 'auto'), task('laid-out', 40, 40, 'auto'), task('free', 0, 0)]

    expect(nudgeIds(nodes, ['laid-out', 'free'])).toEqual(['free'])
    expect(nudgeNodes(nodes, ['laid-out'], 10, 10)).toBe(nodes)
  })

  it('still moves children of a custom group', () => {
    const nodes = [group('custom', 0, 0, 'custom'), task('inside', 40, 40, 'custom')]

    expect(nudgeNodes(nodes, ['inside'], 1, 0)[1].position).toEqual({ x: 41, y: 40 })
  })
})
