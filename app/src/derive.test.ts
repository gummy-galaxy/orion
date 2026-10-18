import { describe, expect, it } from 'vitest'
import { buildWork, deriveSources, sourcesOf, sourcesOfGroup, toServerFacts, type Derived } from './derive'
import type { AppNode, ItemKind, Link, Status, TaskNode } from './model'

const task = (id: string, status: Status = 'todo', itemKind: ItemKind = 'step'): AppNode => ({
  id,
  type: 'task',
  position: { x: 0, y: 0 },
  data: { kind: 'task', label: id, itemKind, status },
})
const taskNode = (id: string): TaskNode => task(id) as TaskNode
const link = (from: string, to: string): Link => ({ id: `${from}>${to}`, from, to, kind: 'blocks' })

describe('card sources', () => {
  it('links pull request and external source badges to their source URLs', () => {
    const pull = taskNode('pull')

    pull.data.repo = 'vocksel/orion'
    pull.data.refs = [{ source: 'github', kind: 'pull', key: 'vocksel/orion#42', url: 'https://github.com/vocksel/orion/pull/42' }]
    const external = taskNode('external')

    external.data.refs = [{ source: 'jira', kind: 'issue', key: 'WORK-7', url: 'https://jira.example.com/browse/WORK-7' }]

    expect(sourcesOf(pull)).toEqual([{ domain: 'github.com', label: 'vocksel/orion#42', href: 'https://github.com/vocksel/orion/pull/42' }])
    expect(sourcesOf(external)).toEqual([{ domain: 'jira.example.com', label: 'WORK-7', href: 'https://jira.example.com/browse/WORK-7' }])
  })

  it('gives every linked ref its own badge and falls back to provenance without a URL', () => {
    const linked = taskNode('linked')
    const unlinked = taskNode('unlinked')

    linked.data.refs = [
      { source: 'hop', kind: 'branch', key: 'vocksel/orion@work' },
      { source: 'jira', kind: 'issue', key: 'ORN-12', url: 'https://jira.example.com/browse/ORN-12' },
    ]
    unlinked.data.refs = [{ source: 'hop', kind: 'branch', key: 'vocksel/orion@work' }]

    expect(sourcesOf(linked)).toEqual([
      { domain: 'hop', label: 'vocksel/orion@work' },
      { domain: 'jira.example.com', label: 'ORN-12', href: 'https://jira.example.com/browse/ORN-12' },
    ])
    expect(sourcesOf(unlinked)).toEqual([{ domain: 'hop', label: 'vocksel/orion@work' }])
  })

  it('shows both the GitHub issue and the pull request on one card', () => {
    const planning = taskNode('planning')

    planning.data.refs = [
      { source: 'github', kind: 'issue', key: 'vocksel/orion#187', url: 'https://github.com/vocksel/orion/issues/187' },
      { source: 'github', kind: 'pull', key: 'vocksel/orion#153', url: 'https://github.com/vocksel/orion/pull/153' },
    ]

    expect(sourcesOf(planning)).toEqual([
      { domain: 'github.com', label: 'vocksel/orion#187', href: 'https://github.com/vocksel/orion/issues/187' },
      { domain: 'github.com', label: 'vocksel/orion#153', href: 'https://github.com/vocksel/orion/pull/153' },
    ])
  })

  it('shows one badge per source, kind, and key, ignoring key case', () => {
    const card = taskNode('card')

    card.data.refs = [
      { source: 'jira', kind: 'issue', key: 'ORN-12', url: 'https://jira.example.com/browse/ORN-12' },
      { source: 'jira', kind: 'issue', key: 'orn-12', url: 'https://jira.example.com/browse/ORN-12' },
      { source: 'jira', kind: 'issue', key: 'ORN-13', url: 'https://jira.example.com/browse/ORN-13' },
    ]

    expect(sourcesOf(card)).toEqual([
      { domain: 'jira.example.com', label: 'ORN-12', href: 'https://jira.example.com/browse/ORN-12' },
      { domain: 'jira.example.com', label: 'ORN-13', href: 'https://jira.example.com/browse/ORN-13' },
    ])
  })

  it('does not link a badge with an invalid ref URL', () => {
    const invalid = taskNode('invalid')

    invalid.data.refs = [{ source: 'jira', kind: 'issue', key: 'ORN-12', url: 'not a URL' }]

    expect(sourcesOf(invalid)).toEqual([{ domain: 'jira', label: 'ORN-12' }])
  })

  it('gives cards without a repository or outside source no badge', () => {
    expect(sourcesOf(taskNode('local'))).toEqual([])
  })
})

describe('group sources', () => {
  it('collects linked refs from cards inside a group', () => {
    const first = taskNode('first')
    const second = taskNode('second')

    first.data.refs = [{ source: 'jira', kind: 'issue', key: 'ORN-12', url: 'https://jira.example.com/browse/ORN-12' }]
    second.data.refs = [{ source: 'jira', kind: 'issue', key: 'ORN-12', url: 'https://jira.example.com/browse/ORN-12' }]

    expect(sourcesOfGroup([first, second])).toEqual([{ domain: 'jira.example.com', label: 'ORN-12', href: 'https://jira.example.com/browse/ORN-12' }])
  })

  it('collects every ref from cards inside a group', () => {
    const planning = taskNode('planning')

    planning.data.refs = [
      { source: 'github', kind: 'issue', key: 'vocksel/orion#187', url: 'https://github.com/vocksel/orion/issues/187' },
      { source: 'github', kind: 'pull', key: 'vocksel/orion#153', url: 'https://github.com/vocksel/orion/pull/153' },
    ]

    expect(sourcesOfGroup([planning]).map((source) => source.label)).toEqual(['vocksel/orion#153', 'vocksel/orion#187'])
  })

  it('gives each group the badges of the cards inside it', () => {
    const group: AppNode = { id: 'group', type: 'cluster', position: { x: 0, y: 0 }, data: { kind: 'cluster', label: 'Work' } }
    const inside = { ...taskNode('inside'), parentId: 'group' } as TaskNode
    const outside = taskNode('outside')

    inside.data.refs = [{ source: 'jira', kind: 'issue', key: 'ORN-12', url: 'https://jira.example.com/browse/ORN-12' }]
    outside.data.refs = [{ source: 'jira', kind: 'issue', key: 'ORN-13', url: 'https://jira.example.com/browse/ORN-13' }]

    const sources = deriveSources([group, inside, outside])

    expect(sources.get('group')).toEqual([{ domain: 'jira.example.com', label: 'ORN-12', href: 'https://jira.example.com/browse/ORN-12' }])
    expect(sources.get('outside')).toEqual([{ domain: 'jira.example.com', label: 'ORN-13', href: 'https://jira.example.com/browse/ORN-13' }])
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
    canvas: { total: 2, done: 0, ready: 1, blocked: 1, outside: 0 },
    snoozed: { b: '2026-10-12T17:00:00Z' },
    attention: { a: true },
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
    expect(work.canvas).toEqual({ total: 2, done: 0, ready: 1, blocked: 1, outside: 0 })
    expect([...work.attention]).toEqual(['a'])
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

  it('gives a component the server has not derived no status', () => {
    const work = buildWork(toServerFacts(null), [task('api', 'todo', 'component')], [])

    expect(work.status.has('api')).toBe(false)
  })
})
