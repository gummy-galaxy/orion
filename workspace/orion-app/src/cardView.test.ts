import { describe, expect, it } from 'vitest'
import { getCardView } from './cardView'
import type { SourceRef } from './derive'
import type { Rarity } from './rarity'
import type { SourceRef as SourceRefData, TaskData, TaskNode, ViewStatus } from './model'

const createTaskData = (overrides: Partial<TaskData> = {}): TaskData => ({
  kind: 'task',
  label: 'Work',
  status: 'todo',
  ...overrides,
})

const createTaskNode = (taskData: TaskData): TaskNode => ({
  id: 'card-1',
  type: 'task',
  position: { x: 0, y: 0 },
  data: taskData,
})
const sources: SourceRef[] = [
  { domain: 'jira.example.com', label: 'ORN-12', href: 'https://jira.example.com/browse/ORN-12' },
]
const createFacts = (status: ViewStatus = 'ready', upstream = 0, rarity: Rarity = 'common') => ({
  status,
  leverage: 3,
  upstream,
  rarity,
  sources,
})

describe('getCardView', () => {
  it('passes through the kind, tag, URL, sources, and card identity', () => {
    const view = getCardView(
      createTaskNode(
        createTaskData({
          label: '',
          repo: 'vocksel/orion',
          note: 'Keep visible',
          refs: [{ source: 'jira', kind: 'issue', key: 'ORN-12', url: 'https://jira.example.com/browse/ORN-12' }],
        }),
      ),
      createFacts(),
    )

    expect(view).toMatchObject({
      id: 'card-1',
      kind: 'step',
      title: '',
      tag: 'ORN-12',
      url: 'https://jira.example.com/browse/ORN-12',
      status: 'ready',
      statusLabel: 'Ready',
      leverage: 3,
      upstream: 0,
      rarity: 'common',
      note: 'Keep visible',
      repo: 'vocksel/orion',
      artSeed: 'card-1',
    })
    expect(view.sources).toBe(sources)
  })

  it('shows the rarity the server derived for work and leaves it absent for notes', () => {
    expect(
      getCardView(createTaskNode(createTaskData({ type: 'gate' })), createFacts('ready', 14, 'mythic')),
    ).toMatchObject({
      upstream: 14,
      rarity: 'mythic',
    })
    const note = getCardView(createTaskNode(createTaskData({ type: 'note' })), createFacts('done', 14, 'mythic'))

    expect(note.upstream).toBe(14)
    expect(note).not.toHaveProperty('rarity')
  })

  it('keeps who only while the card is not done', () => {
    const taskNode = createTaskNode(createTaskData({ who: 'you' }))

    expect(getCardView(taskNode, createFacts())).toMatchObject({ who: 'you', whoLabel: 'Your move' })
    expect(getCardView(taskNode, createFacts('done'))).toMatchObject({ status: 'done', statusLabel: 'Done' })
    expect(getCardView(taskNode, createFacts('done'))).not.toHaveProperty('who')
    expect(getCardView(taskNode, createFacts('done'))).not.toHaveProperty('whoLabel')
  })

  it.each(['passing', 'failing', 'pending'] as const)('carries %s checks', (state) => {
    const taskNode = createTaskNode(
      createTaskData({ refs: [{ source: 'github', kind: 'pull', key: 'vocksel/orion#1', checks: { state } }] }),
    )

    expect(getCardView(taskNode, createFacts()).checks).toBe(state)
  })

  it('omits checks when the pull has no check state', () => {
    const taskNode = createTaskNode(
      createTaskData({ refs: [{ source: 'github', kind: 'pull', key: 'vocksel/orion#1' }] }),
    )

    expect(getCardView(taskNode, createFacts()).checks).toBeUndefined()
    expect(getCardView(createTaskNode(createTaskData()), createFacts()).checks).toBeUndefined()
  })

  it('carries check progress and counts when the source reports them', () => {
    const checks = { state: 'failing', progress: 'running', total: 8, finished: 3, failed: 1 } as const
    const pull = (refChecks: SourceRefData['checks']) =>
      createTaskNode(
        createTaskData({ refs: [{ source: 'github', kind: 'pull', key: 'vocksel/orion#1', checks: refChecks }] }),
      )

    expect(getCardView(pull(checks), createFacts())).toMatchObject({
      checkProgress: 'running',
      checkCounts: { total: 8, finished: 3, failed: 1 },
    })
    expect(getCardView(pull({ state: 'failing' }), createFacts())).not.toHaveProperty('checkCounts')
    expect(getCardView(pull({ state: 'failing' }), createFacts())).not.toHaveProperty('checkProgress')
  })

  it('opens a pull request card from its primary ref, not from another GitHub badge', () => {
    const pullUrl = 'https://github.com/vocksel/orion/pull/153'
    const issueUrl = 'https://github.com/vocksel/orion/issues/187'
    const taskNode = createTaskNode(
      createTaskData({
        refs: [
          { source: 'github', kind: 'pull', key: 'vocksel/orion#153', url: pullUrl },
          { source: 'github', kind: 'issue', key: 'vocksel/orion#187', url: issueUrl },
        ],
      }),
    )
    const badges: SourceRef[] = [
      { domain: 'github.com', label: 'vocksel/orion#153', href: pullUrl },
      { domain: 'github.com', label: 'vocksel/orion#187', href: issueUrl },
    ]

    expect(getCardView(taskNode, { ...createFacts(), sources: badges })).toMatchObject({
      url: pullUrl,
      pullRequestUrl: pullUrl,
    })
  })

  it('does not open a pull request card when its primary ref is not on GitHub', () => {
    const taskNode = createTaskNode(
      createTaskData({
        refs: [{ source: 'jira', kind: 'issue', key: 'ORN-12', url: 'https://jira.example.com/browse/ORN-12' }],
      }),
    )

    expect(getCardView(taskNode, createFacts())).not.toHaveProperty('pullRequestUrl')
  })

  it('offers a merge while GitHub would merge the pull request and the card is still in play', () => {
    const url = 'https://github.com/vocksel/orion/pull/1'
    const taskNode = createTaskNode(
      createTaskData({
        refs: [
          {
            source: 'github',
            kind: 'pull',
            key: 'vocksel/orion#1',
            url,
            readiness: 'mergeable',
            checks: { state: 'passing' },
            head: 'abc123',
          },
        ],
      }),
    )

    expect(getCardView(taskNode, createFacts('review'))).toMatchObject({
      readiness: 'mergeable',
      readyToMerge: true,
      statusLabel: 'Ready to merge',
      merge: { url, head: 'abc123' },
    })
    expect(getCardView(taskNode, createFacts('blocked'))).toMatchObject({
      readiness: 'mergeable',
      statusLabel: 'Blocked',
    })
    expect(getCardView(taskNode, createFacts('blocked'))).not.toHaveProperty('readyToMerge')
    expect(getCardView(taskNode, createFacts('blocked'))).not.toHaveProperty('merge')
  })

  it('shows the pull request facts the server derived with snoozed jobs left out', () => {
    const node = createTaskNode(
      createTaskData({
        refs: [
          {
            source: 'github',
            kind: 'pull',
            key: 'vocksel/orion#341',
            url: 'https://github.com/vocksel/orion/pull/341',
            readiness: 'failing',
            checks: { state: 'failing', total: 3, finished: 3, failed: 1 },
          },
        ],
      }),
    )
    const snoozedFacts = {
      readiness: 'passing' as const,
      checks: { state: 'passing' as const, total: 3, finished: 3, failed: 0 },
      snoozed: [{ name: 'docs' }],
    }

    expect(getCardView(node, createFacts('review')).readiness).toBe('failing')
    expect(getCardView(node, { ...createFacts('review'), snoozedFacts }).readiness).toBe('passing')
    expect(getCardView(node, { ...createFacts('review'), snoozedFacts }).checks).toBe('passing')
  })
})
