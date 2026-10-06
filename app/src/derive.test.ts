import { describe, expect, it } from 'vitest'
import { deriveWork } from './derive'
import type { AppNode, ItemKind, Link, Status } from './model'

const task = (id: string, status: Status = 'todo', itemKind: ItemKind = 'step'): AppNode => ({
  id,
  type: 'task',
  position: { x: 0, y: 0 },
  data: { kind: 'task', label: id, itemKind, status },
})
const link = (from: string, to: string): Link => ({ id: `${from}>${to}`, from, to, kind: 'blocks' })

describe('deriveWork flow', () => {
  it('moves out of work that can start and holds after work that waits', () => {
    const { flow } = deriveWork([task('a'), task('b'), task('c')], [link('a', 'b'), link('b', 'c')])
    expect(flow.get('a')).toBe('live')
    expect(flow.get('b')).toBe('held')
  })

  it('holds after blocked or deferred work and settles after done work', () => {
    const { flow } = deriveWork([task('blocked', 'blocked'), task('deferred', 'deferred'), task('done', 'done')], [])
    expect(flow.get('blocked')).toBe('held')
    expect(flow.get('deferred')).toBe('held')
    expect(flow.get('done')).toBe('done')
  })

  it('passes flow through notes', () => {
    const nodes = [task('ready'), task('waiting'), task('n1', 'todo', 'note'), task('n2', 'todo', 'note'), task('x'), task('y')]
    const { flow } = deriveWork(nodes, [link('ready', 'n1'), link('n1', 'x'), link('ready', 'waiting'), link('waiting', 'n2'), link('n2', 'y')])
    expect(flow.get('n1')).toBe('live')
    expect(flow.get('n2')).toBe('held')
  })
})
