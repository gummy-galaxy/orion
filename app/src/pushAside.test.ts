import { describe, expect, it } from 'vitest'
import { GAP } from './layout'
import { TASK_HEIGHT, TASK_WIDTH, byId, normalize, sizeOf, type AppNode } from './model'
import { pushAside } from './pushAside'

const size = { width: TASK_WIDTH, height: TASK_HEIGHT }

const task = (id: string, parentId: string | undefined, x: number, y: number): AppNode => ({
  id,
  type: 'task',
  parentId,
  position: { x, y },
  data: { kind: 'task', label: id, itemKind: 'step', status: 'todo' },
})
const cluster = (id: string, parentId: string | undefined, x: number, y: number): AppNode => ({
  id,
  type: 'cluster',
  parentId,
  position: { x, y },
  data: { kind: 'cluster', label: id },
})

const at = (nodes: AppNode[], id: string) => byId(nodes).get(id)!.position
const rightOf = (nodes: AppNode[], id: string) => at(nodes, id).x + sizeOf(byId(nodes).get(id)!, size).width
const bottomOf = (nodes: AppNode[], id: string) => at(nodes, id).y + sizeOf(byId(nodes).get(id)!, size).height

/** Two top-level groups side by side, `a` holding one card and `b` starting one standard gap to its right. */
function sideBySide(): AppNode[] {
  const start = normalize([cluster('a', undefined, 0, 0), task('a1', 'a', 32, 78)])

  return normalize([...start, cluster('b', undefined, rightOf(start, 'a') + GAP.top.x, 0), task('b1', 'b', 32, 78)])
}

describe('pushAside', () => {
  it('moves a neighbor right when a group grows into it, keeping the gap', () => {
    const previous = sideBySide()
    const next = normalize([...previous, task('a2', 'a', 32 + TASK_WIDTH + GAP.inner.x, 78)])

    expect(rightOf(next, 'a')).toBeGreaterThan(at(next, 'b').x)

    const pushed = pushAside(previous, next, size)

    expect(at(pushed, 'b').x).toBe(rightOf(pushed, 'a') + GAP.top.x)
    expect(at(pushed, 'b').y).toBe(0)
  })

  it('moves a neighbor down when a group grows taller', () => {
    const start = normalize([cluster('a', undefined, 0, 0), task('a1', 'a', 32, 78)])
    const previous = normalize([...start, cluster('c', undefined, 0, bottomOf(start, 'a') + 40), task('c1', 'c', 32, 78)])
    const next = normalize([...previous, task('a2', 'a', 32, 78 + TASK_HEIGHT + GAP.inner.y)])

    const pushed = pushAside(previous, next, size)

    expect(at(pushed, 'c').y).toBe(bottomOf(pushed, 'a') + 40)
  })

  it('carries the push through nested groups and up to the top level', () => {
    const inner = normalize([cluster('p', undefined, 0, 0), cluster('s1', 'p', 32, 78), task('s1a', 's1', 32, 78)])
    const withSecond = normalize([...inner, cluster('s2', 'p', rightOf(inner, 's1') + GAP.inner.x, 78), task('s2a', 's2', 32, 78)])
    const previous = normalize([...withSecond, cluster('q', undefined, rightOf(withSecond, 'p') + GAP.top.x, 0), task('q1', 'q', 32, 78)])
    const next = normalize([...previous, task('s1b', 's1', 32 + TASK_WIDTH + GAP.inner.x, 78)])

    const pushed = pushAside(previous, next, size)

    expect(at(pushed, 's2').x).toBe(rightOf(pushed, 's1') + GAP.inner.x)
    expect(at(pushed, 'q').x).toBe(rightOf(pushed, 'p') + GAP.top.x)
  })

  it('pushes each neighbor along a row in turn', () => {
    const previous = sideBySide()
    const third = normalize([...previous, cluster('c', undefined, rightOf(previous, 'b') + 40, 0), task('c1', 'c', 32, 78)])
    const next = normalize([...third, task('a2', 'a', 32 + TASK_WIDTH + GAP.inner.x, 78)])

    const pushed = pushAside(third, next, size)

    expect(at(pushed, 'c').x).toBe(rightOf(pushed, 'b') + 40)
  })

  it('leaves neighbors that are still clear alone, and returns the same nodes when nothing moves', () => {
    const start = normalize([cluster('a', undefined, 0, 0), task('a1', 'a', 32, 78)])
    const previous = normalize([...start, cluster('far', undefined, 5000, 0), task('f1', 'far', 32, 78)])
    const next = normalize([...previous, task('a2', 'a', 32 + TASK_WIDTH + GAP.inner.x, 78)])

    expect(pushAside(previous, next, size)).toBe(next)
    expect(pushAside(previous, previous, size)).toBe(previous)
  })

  it('changes nothing when run again on its own result', () => {
    const previous = sideBySide()
    const next = normalize([...previous, task('a2', 'a', 32 + TASK_WIDTH + GAP.inner.x, 78)])
    const pushed = pushAside(previous, next, size)

    expect(pushAside(previous, pushed, size)).toBe(pushed)
  })
})

describe('pushAside after a drag', () => {
  it('lets a group be dragged past its neighbor without pushing it', () => {
    const previous = sideBySide()
    const next = normalize(previous.map((node) => (node.id === 'a' ? { ...node, position: { x: rightOf(previous, 'b') + GAP.top.x, y: 0 } } : node)))

    expect(pushAside(previous, next, size)).toBe(next)
  })
})
