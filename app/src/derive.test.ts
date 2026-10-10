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

    pull.data.repo = 'vocksel/orion'
    pull.data.refs = [{ source: 'github', kind: 'pull', key: 'vocksel/orion#42', url: 'https://github.com/vocksel/orion/pull/42' }]
    const external = task('external') as TaskNode

    external.data.refs = [{ source: 'jira', kind: 'issue', key: 'WORK-7', url: 'https://jira.example.com/browse/WORK-7' }]

    const { sources } = deriveWork([pull, external], [])

    expect(sources.get('pull')).toEqual([{ domain: 'github.com', label: 'vocksel/orion#42', href: 'https://github.com/vocksel/orion/pull/42' }])
    expect(sources.get('external')).toEqual([{ domain: 'jira.example.com', label: 'WORK-7', href: 'https://jira.example.com/browse/WORK-7' }])
  })

  it('uses the first linked ref and falls back to provenance without a URL', () => {
    const linked = task('linked') as TaskNode
    const unlinked = task('unlinked') as TaskNode

    linked.data.refs = [
      { source: 'hop', kind: 'branch', key: 'vocksel/orion@work' },
      { source: 'jira', kind: 'issue', key: 'ORN-12', url: 'https://jira.example.com/browse/ORN-12' },
    ]
    unlinked.data.refs = [{ source: 'hop', kind: 'branch', key: 'vocksel/orion@work' }]

    const { sources } = deriveWork([linked, unlinked], [])

    expect(sources.get('linked')).toEqual([{ domain: 'jira.example.com', label: 'ORN-12', href: 'https://jira.example.com/browse/ORN-12' }])
    expect(sources.get('unlinked')).toEqual([{ domain: 'hop', label: 'vocksel/orion@work' }])
  })

  it('does not link a badge with an invalid ref URL', () => {
    const invalid = task('invalid') as TaskNode

    invalid.data.refs = [{ source: 'jira', kind: 'issue', key: 'ORN-12', url: 'not a URL' }]

    expect(deriveWork([invalid], []).sources.get('invalid')).toEqual([{ domain: 'jira', label: 'ORN-12' }])
  })

  it('gives cards without a repository or outside source no badge', () => {
    const { sources } = deriveWork([task('local')], [])

    expect(sources.get('local')).toEqual([])
  })

  it('collects linked refs from cards inside a group', () => {
    const group: AppNode = { id: 'group', type: 'cluster', position: { x: 0, y: 0 }, data: { kind: 'cluster', label: 'Work' } }
    const first = { ...task('first'), parentId: 'group' } as TaskNode
    const second = { ...task('second'), parentId: 'group' } as TaskNode

    first.data.refs = [{ source: 'jira', kind: 'issue', key: 'ORN-12', url: 'https://jira.example.com/browse/ORN-12' }]
    second.data.refs = [{ source: 'jira', kind: 'issue', key: 'ORN-12', url: 'https://jira.example.com/browse/ORN-12' }]

    const { sources } = deriveWork([group, first, second], [])

    expect(sources.get('group')).toEqual([{ domain: 'jira.example.com', label: 'ORN-12', href: 'https://jira.example.com/browse/ORN-12' }])
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
