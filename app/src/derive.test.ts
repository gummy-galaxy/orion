import { describe, expect, it } from 'vitest'
import { deriveWork } from './derive'
import type { AppNode, ItemKind, Link, Status, TaskNode } from './model'

const task = (id: string, status: Status = 'todo', itemKind: ItemKind = 'step'): AppNode => ({
  id,
  type: 'task',
  position: { x: 0, y: 0 },
  data: { kind: 'task', label: id, itemKind, status },
})
const link = (from: string, to: string): Link => ({ id: `${from}>${to}`, from, to, kind: 'blocks' })

describe('deriveWork sources', () => {
  it('links pull request and external source badges to their source URLs', () => {
    const pull = task('pull') as TaskNode

    pull.data.repo = 'orion'
    pull.data.pr = 42
    const external = task('external') as TaskNode

    external.data.external = { source: 'jira', key: 'WORK-7', url: 'https://jira.example.com/browse/WORK-7' }

    const { sources } = deriveWork([pull, external], [], 'vocksel')

    expect(sources.get('pull')).toEqual([{ domain: 'github.com', label: 'orion', href: 'https://github.com/vocksel/orion/pull/42' }])
    expect(sources.get('external')).toEqual([{ domain: 'jira.example.com', label: 'WORK-7', href: 'https://jira.example.com/browse/WORK-7' }])
  })

  it('gives cards without a repository or outside source no badge', () => {
    const { sources } = deriveWork([task('local')], [])

    expect(sources.get('local')).toEqual([])
  })
})

describe('deriveWork gates', () => {
  it('finishes a gate once everything it waits on is done', () => {
    const links = [link('a', 'g'), link('b', 'g'), link('g', 'c')]
    const waiting = deriveWork([task('a', 'done'), task('b', 'active'), task('g', 'todo', 'gate'), task('c', 'todo')], links)

    expect(waiting.status.get('g')).toBe('blocked')
    expect(waiting.status.get('c')).toBe('blocked')
    expect(waiting.leverage.get('b')).toBe(2)

    const finished = deriveWork([task('a', 'done'), task('b', 'done'), task('g', 'todo', 'gate'), task('c', 'todo')], links)

    expect(finished.status.get('g')).toBe('done')
    expect(finished.status.get('c')).toBe('ready')
  })

  it('counts the rounds of open work before a waiting card can start', () => {
    const links = [link('a', 'b'), link('b', 'n'), link('n', 'c'), link('done', 'c')]
    const work = deriveWork([task('a', 'active'), task('b', 'todo'), task('n', 'todo', 'note'), task('c', 'todo'), task('done', 'done')], links)

    expect(work.behind.get('a')).toBeUndefined()
    expect(work.behind.get('b')).toBe(1)
    expect(work.behind.get('c')).toBe(2)
  })

  it('treats a gate with nothing to wait on as ordinary work', () => {
    expect(deriveWork([task('g', 'todo', 'gate')], []).status.get('g')).toBe('ready')
  })
})

describe('deriveWork flow', () => {
  it('moves out of work that can start and holds after work that waits', () => {
    const { flow } = deriveWork([task('a'), task('b'), task('c')], [link('a', 'b'), link('b', 'c')])

    expect(flow.get('a')).toBe('live')
    expect(flow.get('b')).toBe('held')
  })

  it('holds after blocked or deferred work and keeps moving after done work', () => {
    const { flow } = deriveWork([task('blocked', 'blocked'), task('deferred', 'deferred'), task('done', 'done')], [])

    expect(flow.get('blocked')).toBe('held')
    expect(flow.get('deferred')).toBe('held')
    expect(flow.get('done')).toBe('live')
  })

  it('passes flow through notes', () => {
    const nodes = [task('ready'), task('waiting'), task('n1', 'todo', 'note'), task('n2', 'todo', 'note'), task('x'), task('y')]
    const { flow } = deriveWork(nodes, [link('ready', 'n1'), link('n1', 'x'), link('ready', 'waiting'), link('waiting', 'n2'), link('n2', 'y')])

    expect(flow.get('n1')).toBe('live')
    expect(flow.get('n2')).toBe('held')
  })
})
