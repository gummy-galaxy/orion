// @vitest-environment happy-dom
import { act, renderHook } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import type { AppNode } from './model'
import type { Saved } from './persist'
import { useUndo } from './useUndo'

const SETTLE_MS = 300

const makeNode = (id: string, x = 0, label = id): AppNode => ({
  id,
  type: 'task',
  position: { x, y: 0 },
  data: { kind: 'task', label, itemKind: 'step', status: 'todo' },
})
const makeDoc = (...nodes: AppNode[]): Saved => ({ nodes, links: [], stickers: [], stickerLoadout: [] })
const positions = (doc: Saved) => Object.fromEntries(doc.nodes.map((node) => [node.id, node.position.x]))

/** Renders the hook against a document the test edits, the way the canvas would. */
function setup(initial: Saved) {
  let doc = initial
  let busy = false
  const apply = vi.fn((next: Saved) => {
    doc = next
    view.rerender()

    return next
  })
  const view = renderHook(() => useUndo({ doc, busy, getDoc: () => doc, apply }))

  const edit = (next: Saved) => {
    doc = next
    view.rerender()
  }

  const settle = () => vi.advanceTimersByTime(SETTLE_MS)

  const setBusy = (next: boolean) => {
    busy = next
    view.rerender()
  }

  return { view, apply, edit, settle, setBusy, current: () => doc }
}

describe('useUndo', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  it('records an edit once it settles and takes it back', () => {
    const canvas = setup(makeDoc(makeNode('a', 0)))

    canvas.edit(makeDoc(makeNode('a', 100)))
    expect(canvas.view.result.current.canUndo).toBe(false)

    act(canvas.settle)
    expect(canvas.view.result.current.canUndo).toBe(true)

    act(() => canvas.view.result.current.undo())
    expect(positions(canvas.current())).toEqual({ a: 0 })
    expect(canvas.view.result.current).toMatchObject({ canUndo: false, canRedo: true })

    act(() => canvas.view.result.current.redo())
    expect(positions(canvas.current())).toEqual({ a: 100 })
  })

  it('folds changes that land close together into one step', () => {
    const canvas = setup(makeDoc(makeNode('a', 0)))

    for (const x of [10, 20, 30]) {
      canvas.edit(makeDoc(makeNode('a', x)))
      act(() => vi.advanceTimersByTime(SETTLE_MS / 2))
    }

    act(canvas.settle)
    act(() => canvas.view.result.current.undo())

    expect(positions(canvas.current())).toEqual({ a: 0 })
    expect(canvas.view.result.current.canUndo).toBe(false)
  })

  it('holds a step open while busy, such as mid-drag', () => {
    const canvas = setup(makeDoc(makeNode('a', 0)))

    canvas.setBusy(true)
    canvas.edit(makeDoc(makeNode('a', 50)))
    act(() => vi.advanceTimersByTime(SETTLE_MS * 4))
    canvas.edit(makeDoc(makeNode('a', 100)))
    act(() => vi.advanceTimersByTime(SETTLE_MS * 4))
    expect(canvas.view.result.current.canUndo).toBe(false)

    canvas.setBusy(false)
    act(canvas.settle)
    act(() => canvas.view.result.current.undo())

    expect(positions(canvas.current())).toEqual({ a: 0 })
    expect(canvas.view.result.current.canUndo).toBe(false)
  })

  it('takes back an edit that is still settling', () => {
    const canvas = setup(makeDoc(makeNode('a', 0)))

    canvas.edit(makeDoc(makeNode('a', 100)))
    act(() => canvas.view.result.current.undo())

    expect(positions(canvas.current())).toEqual({ a: 0 })
  })

  it("doesn't record writes from elsewhere, and keeps them through undo", () => {
    const canvas = setup(makeDoc(makeNode('a', 0)))

    canvas.edit(makeDoc(makeNode('a', 100)))
    act(canvas.settle)

    const remote = makeDoc(makeNode('a', 100, 'renamed by the CLI'), makeNode('b', 5))

    act(() => canvas.view.result.current.rebase(remote))
    canvas.edit(remote)
    act(canvas.settle)

    act(() => canvas.view.result.current.undo())

    expect(positions(canvas.current())).toEqual({ a: 0, b: 5 })
    expect(canvas.current().nodes[0].data).toMatchObject({ label: 'renamed by the CLI' })
    expect(canvas.view.result.current.canUndo).toBe(false)
  })

  it('keeps an edit still settling as its own step when a write arrives', () => {
    const canvas = setup(makeDoc(makeNode('a', 0)))

    canvas.edit(makeDoc(makeNode('a', 100)))

    const remote = makeDoc(makeNode('a', 100), makeNode('b', 5))

    act(() => canvas.view.result.current.rebase(remote))
    canvas.edit(remote)
    act(canvas.settle)
    act(() => canvas.view.result.current.undo())

    expect(positions(canvas.current())).toEqual({ a: 0, b: 5 })
  })

  it('starts over on reset', () => {
    const canvas = setup(makeDoc(makeNode('a', 0)))

    canvas.edit(makeDoc(makeNode('a', 100)))
    act(canvas.settle)

    const other = makeDoc(makeNode('z', 7))

    act(() => canvas.view.result.current.reset(other))
    canvas.edit(other)
    act(canvas.settle)

    expect(canvas.view.result.current).toMatchObject({ canUndo: false, canRedo: false })

    act(() => canvas.view.result.current.undo())
    expect(canvas.apply).not.toHaveBeenCalled()
  })

  it('ignores changes that only touch view state', () => {
    const canvas = setup(makeDoc(makeNode('a', 0)))

    canvas.edit(makeDoc({ ...makeNode('a', 0), selected: true } as AppNode))
    act(canvas.settle)

    expect(canvas.view.result.current.canUndo).toBe(false)
  })
})
