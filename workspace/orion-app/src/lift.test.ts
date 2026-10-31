import { describe, expect, it } from 'vitest'
import { DRAG_LIFT_Z, liftNodes, unliftNodes } from './lift'
import type { AppNode } from './model'

const task = (id: string, zIndex?: number): AppNode => ({
  id,
  type: 'task',
  zIndex,
  position: { x: 0, y: 0 },
  data: { kind: 'task', label: id, status: 'todo' },
})

describe('drag lift', () => {
  it('lifts only the dragged nodes and keeps the others as they were', () => {
    const nodes = [task('a'), task('b'), task('c')]
    const lifted = liftNodes(nodes, new Set(['a']))

    expect(lifted.map((node) => node.zIndex)).toEqual([DRAG_LIFT_Z, undefined, undefined])
    expect(lifted[1]).toBe(nodes[1])
    expect(lifted[2]).toBe(nodes[2])
  })

  it('returns the same array when the dragged nodes are already lifted', () => {
    const nodes = liftNodes([task('a'), task('b')], new Set(['a']))

    expect(liftNodes(nodes, new Set(['a']))).toBe(nodes)
    expect(liftNodes(nodes, new Set(['z']))).toBe(nodes)
  })

  it('drops the lift from released nodes and leaves other z-indexes alone', () => {
    const nodes = [task('a', DRAG_LIFT_Z), task('b', DRAG_LIFT_Z), task('ghost', 5)]
    const released = unliftNodes(nodes, new Set(['a']))

    expect(released.map((node) => node.zIndex)).toEqual([undefined, DRAG_LIFT_Z, 5])
  })

  it('returns the same array when nothing is lifted', () => {
    const nodes = [task('a'), task('b')]

    expect(unliftNodes(nodes, new Set(['a']))).toBe(nodes)
  })
})
