import { describe, expect, it } from 'vitest'
import { deriveWork, sourcesOf, sourcesOfGroup } from './derive'
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

describe('deriveWork upstream', () => {
  it('counts a chain including completed work and gates', () => {
    const { upstream } = deriveWork([task('a', 'done'), task('b'), task('gate', 'todo', 'gate')], [link('a', 'b'), link('b', 'gate')])

    expect([...upstream]).toEqual([
      ['a', 0],
      ['b', 1],
      ['gate', 2],
    ])
  })

  it('counts a shared ancestor once in a diamond', () => {
    const { upstream } = deriveWork([task('a'), task('b'), task('c'), task('d')], [link('a', 'b'), link('a', 'c'), link('b', 'd'), link('c', 'd')])

    expect(upstream.get('d')).toBe(3)
  })

  it('passes through notes without counting them', () => {
    const { upstream } = deriveWork([task('a'), task('note', 'todo', 'note'), task('b')], [link('a', 'note'), link('note', 'b')])

    expect(upstream.get('b')).toBe(1)
  })

  it('ignores related links', () => {
    const { upstream } = deriveWork([task('a'), task('b')], [{ ...link('a', 'b'), kind: 'related' }])

    expect(upstream.get('b')).toBe(0)
  })

  it('terminates a cycle and excludes the card itself', () => {
    const { upstream } = deriveWork(
      [task('a'), task('b'), task('note', 'todo', 'note'), task('c')],
      [link('a', 'b'), link('b', 'note'), link('note', 'a'), link('b', 'c')],
    )

    expect(upstream.get('a')).toBe(1)
    expect(upstream.get('b')).toBe(1)
    expect(upstream.get('c')).toBe(2)
  })
})

describe('deriveWork group progress', () => {
  it('leaves deferred work out of the total', () => {
    const group: AppNode = { id: 'group', type: 'cluster', position: { x: 0, y: 0 }, data: { kind: 'cluster', label: 'Work' } }
    const inGroup = (node: AppNode) => ({ ...node, parentId: 'group' }) as AppNode
    const nodes = [
      group,
      inGroup(task('shipped', 'done')),
      inGroup(task('next')),
      inGroup(task('parked', 'deferred')),
      inGroup(task('note', 'todo', 'note')),
    ]

    expect(deriveWork(nodes, []).groups.get('group')).toEqual({ total: 2, done: 1, ready: 1, blocked: 0, outside: 0 })
  })
})
