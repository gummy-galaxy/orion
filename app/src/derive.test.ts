import { describe, expect, it } from 'vitest'
import { deriveWork } from './derive'
import type { AppNode, ItemKind, Link, Status } from './model'

const task = (id: string, status: Status, itemKind: ItemKind = 'step'): AppNode => ({
  id,
  type: 'task',
  position: { x: 0, y: 0 },
  data: { kind: 'task', label: id, itemKind, status },
})
const blocks = (from: string, to: string): Link => ({ id: `${from}>${to}`, from, to, kind: 'blocks' })

describe('deriveWork', () => {
  it('finishes a gate once everything it waits on is done', () => {
    const links = [blocks('a', 'g'), blocks('b', 'g'), blocks('g', 'c')]
    const waiting = deriveWork([task('a', 'done'), task('b', 'active'), task('g', 'todo', 'gate'), task('c', 'todo')], links)
    expect(waiting.status.get('g')).toBe('blocked')
    expect(waiting.status.get('c')).toBe('blocked')
    expect(waiting.leverage.get('b')).toBe(2)

    const open = deriveWork([task('a', 'done'), task('b', 'done'), task('g', 'todo', 'gate'), task('c', 'todo')], links)
    expect(open.status.get('g')).toBe('done')
    expect(open.status.get('c')).toBe('ready')
  })

  it('treats a gate with nothing to wait on as ordinary work', () => {
    expect(deriveWork([task('g', 'todo', 'gate')], []).status.get('g')).toBe('ready')
  })
})
