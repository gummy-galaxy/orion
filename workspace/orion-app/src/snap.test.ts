import { describe, expect, it } from 'vitest'
import { finishDrag, snapDrag, snapGuides } from './snap'
import type { AppNode } from './model'

/** Matches SNAP_REACH_PX at zoom 1. */
const REACH = 160

const task = (id: string, x: number, y: number): AppNode => ({
  id,
  type: 'task',
  position: { x, y },
  data: { kind: 'task', label: id, itemKind: 'step', status: 'todo' },
})

describe('drag snapping', () => {
  it('aligns a dragged card with a nearby card', () => {
    const nodes = [task('reference', 0, 200), task('dragged', 5, 0)]

    expect(snapDrag(nodes, ['dragged'], 8, REACH)[1].position).toEqual({ x: 0, y: 0 })
  })

  it('still snaps to a neighbor one normal gap away', () => {
    // Top-level cards are 216 wide with 120 between them, the widest gap the layout leaves.
    const nodes = [task('neighbor', 0, 0), task('dragged', 216 + 120 + 3, 0)]

    expect(snapDrag(nodes, ['dragged'], 8, REACH)[1].position).toEqual({ x: 216 + 120, y: 0 })
  })

  it('ignores a sibling past reach even when its edge lines up', () => {
    // The dragged card sits 200 units below the far one, past the 160 reach.
    const nodes = [task('far', 0, 0), task('dragged', 3, 72 + 200)]

    expect(snapDrag(nodes, ['dragged'], 8, REACH)[1].position).toEqual({ x: 3, y: 72 + 200 })
  })

  it('prefers the nearest sibling when two line up equally well', () => {
    // Both siblings are 2 units off the dragged card's left edge. `near` is 72 units away and `far` is 134.
    const nodes = [task('far', 4, 350), task('near', 0, 0), task('dragged', 2, 144)]

    expect(snapDrag(nodes, ['dragged'], 8, REACH)[2].position).toEqual({ x: 0, y: 144 })
  })

  it('draws guides only for siblings within reach', () => {
    const dragging = (id: string, x: number, y: number): AppNode => ({ ...task(id, x, y), dragging: true })

    expect(snapGuides([task('far', 0, 0), dragging('dragged', 0, 72 + 200)], REACH)).toEqual([])
    expect(
      snapGuides([task('near', 0, 0), dragging('dragged', 0, 72 + 72)], REACH).some((guide) => guide.kind === 'line'),
    ).toBe(true)
  })

  it('restores an arranged card after snapping during the drag', () => {
    const nodes = [task('reference', 216, 0), task('dragged', 216, 0)]
    const origins = new Map([['dragged', { x: 0, y: 0 }]])

    expect(finishDrag(nodes, origins, ['dragged'], false, false)[1].position).toEqual({ x: 0, y: 0 })
  })

  it('skips drop settling when Ctrl is held', () => {
    const nodes = [task('reference', 0, 0), task('dragged', 0, 0)]

    expect(finishDrag(nodes, new Map(), ['dragged'], true, false)).toBe(nodes)
    expect(finishDrag(nodes, new Map(), ['dragged'], false, false)[1].position).not.toEqual({ x: 0, y: 0 })
  })
})
