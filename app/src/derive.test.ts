import { describe, expect, it } from 'vitest'
import { buildWork, deriveSources, needsAttention, toServerFacts, type Derived } from './derive'
import type { AppNode, ItemKind, Link, Status, TaskNode, ViewStatus } from './model'

const task = (id: string, status: Status = 'todo', itemKind: ItemKind = 'step'): AppNode => ({
  id,
  type: 'task',
  position: { x: 0, y: 0 },
  data: { kind: 'task', label: id, itemKind, status },
})
const link = (from: string, to: string): Link => ({ id: `${from}>${to}`, from, to, kind: 'blocks' })

describe('deriveSources', () => {
  it('links pull request and external source badges to their source URLs', () => {
    const pull = task('pull') as TaskNode

    pull.data.repo = 'vocksel/orion'
    pull.data.refs = [{ source: 'github', kind: 'pull', key: 'vocksel/orion#42', url: 'https://github.com/vocksel/orion/pull/42' }]
    const external = task('external') as TaskNode

    external.data.refs = [{ source: 'jira', kind: 'issue', key: 'WORK-7', url: 'https://jira.example.com/browse/WORK-7' }]

    const sources = deriveSources([pull, external])

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

    const sources = deriveSources([linked, unlinked])

    expect(sources.get('linked')).toEqual([{ domain: 'jira.example.com', label: 'ORN-12', href: 'https://jira.example.com/browse/ORN-12' }])
    expect(sources.get('unlinked')).toEqual([{ domain: 'hop', label: 'vocksel/orion@work' }])
  })

  it('does not link a badge with an invalid ref URL', () => {
    const invalid = task('invalid') as TaskNode

    invalid.data.refs = [{ source: 'jira', kind: 'issue', key: 'ORN-12', url: 'not a URL' }]

    expect(deriveSources([invalid]).get('invalid')).toEqual([{ domain: 'jira', label: 'ORN-12' }])
  })

  it('gives cards without a repository or outside source no badge', () => {
    const sources = deriveSources([task('local')])

    expect(sources.get('local')).toEqual([])
  })

  it('collects linked refs from cards inside a group', () => {
    const group: AppNode = { id: 'group', type: 'cluster', position: { x: 0, y: 0 }, data: { kind: 'cluster', label: 'Work' } }
    const first = { ...task('first'), parentId: 'group' } as TaskNode
    const second = { ...task('second'), parentId: 'group' } as TaskNode

    first.data.refs = [{ source: 'jira', kind: 'issue', key: 'ORN-12', url: 'https://jira.example.com/browse/ORN-12' }]
    second.data.refs = [{ source: 'jira', kind: 'issue', key: 'ORN-12', url: 'https://jira.example.com/browse/ORN-12' }]

    const sources = deriveSources([group, first, second])

    expect(sources.get('group')).toEqual([{ domain: 'jira.example.com', label: 'ORN-12', href: 'https://jira.example.com/browse/ORN-12' }])
  })
})

describe('buildWork', () => {
  const derived: Derived = {
    status: { a: 'blocked', b: 'ready' },
    flow: { a: 'held', b: 'live' },
    leverage: { a: 2, b: 0 },
    upstream: { a: 3, b: 0 },
    rarity: { a: 'rare', b: 'common' },
    groups: { g: { total: 2, done: 0, ready: 1, blocked: 1, outside: 0 } },
    snoozed: { b: '2026-10-12T17:00:00Z' },
  }

  it('reads the server values for each card and group', () => {
    const group: AppNode = { id: 'g', type: 'cluster', position: { x: 0, y: 0 }, data: { kind: 'cluster', label: 'Work' } }
    const work = buildWork(toServerFacts(derived), [task('a', 'blocked'), task('b'), group], [link('a', 'b')])

    expect(work.status.get('a')).toBe('blocked')
    expect(work.flow.get('a')).toBe('held')
    expect(work.leverage.get('a')).toBe(2)
    expect(work.upstream.get('a')).toBe(3)
    expect(work.rarity.get('a')).toBe('rare')
    expect(work.groups.get('g')).toEqual({ total: 2, done: 0, ready: 1, blocked: 1, outside: 0 })
    expect(work.snoozed.get('b')).toBe('2026-10-12T17:00:00Z')
  })

  it('keeps blocking links for hover tracing', () => {
    const work = buildWork(toServerFacts(derived), [task('a'), task('b')], [link('a', 'b')])

    expect(work.succs.get('a')).toEqual(['b'])
    expect(work.preds.get('b')).toEqual(['a'])
  })

  it('shows recorded status for cards the server has not derived, without blocking or rarity', () => {
    const work = buildWork(toServerFacts(null), [task('todo'), task('finished', 'done'), task('waiting')], [link('finished', 'waiting')])

    expect(work.status.get('todo')).toBe('ready')
    expect(work.status.get('finished')).toBe('done')
    expect(work.status.get('waiting')).toBe('ready')
    expect(work.flow.get('todo')).toBeUndefined()
    expect(work.rarity.get('todo')).toBeUndefined()
    expect(work.leverage.get('finished')).toBeUndefined()
  })

  it('prefers the server status over the recorded one', () => {
    const work = buildWork(toServerFacts({ ...derived, status: { a: 'blocked' } }), [task('a', 'todo')], [])

    expect(work.status.get('a')).toBe('blocked')
  })
})

describe('needsAttention', () => {
  const yours = (id: string): AppNode => ({ ...task(id), data: { ...task(id).data, who: 'you' } }) as AppNode

  it('lists open work where it is your move', () => {
    const status = new Map<string, ViewStatus>([
      ['a', 'ready'],
      ['b', 'active'],
    ])

    expect(needsAttention([yours('a'), yours('b')], status, new Map())).toEqual(['a', 'b'])
  })

  it('leaves out snoozed work until it wakes', () => {
    const status = new Map<string, ViewStatus>([
      ['a', 'ready'],
      ['b', 'ready'],
    ])

    expect(needsAttention([yours('a'), yours('b')], status, new Map([['a', '2026-10-12T17:00:00Z']]))).toEqual(['b'])
  })
})
