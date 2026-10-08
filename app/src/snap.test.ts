import { describe, expect, it } from 'vitest'
import { finishDrag, snapDrag } from './snap'
import type { AppNode } from './model'

const task = (id: string, x: number, y: number): AppNode => ({
  id,
  type: 'task',
  position: { x, y },
  data: { kind: 'task', label: id, itemKind: 'step', status: 'todo' },
})

describe('drag snapping', () => {
  it('aligns a dragged card with a nearby card', () => {
    const nodes = [task('reference', 0, 200), task('dragged', 5, 0)]
    expect(snapDrag(nodes, ['dragged'], 8)[1].position).toEqual({ x: 0, y: 0 })
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
