import { describe, expect, it } from 'vitest'
import { getCardView } from './cardView'
import type { SourceRef } from './derive'
import type { Rarity } from './rarity'
import type { TaskData, TaskNode, ViewStatus } from './model'

const createTaskData = (overrides: Partial<TaskData> = {}): TaskData => ({
  kind: 'task',
  itemKind: 'step',
  label: 'Work',
  status: 'todo',
  ...overrides,
})

const createTaskNode = (taskData: TaskData): TaskNode => ({ id: 'card-1', type: 'task', position: { x: 0, y: 0 }, data: taskData })
const sources: SourceRef[] = [{ domain: 'jira.example.com', label: 'ORN-12', href: 'https://jira.example.com/browse/ORN-12' }]
const createFacts = (status: ViewStatus = 'ready', upstream = 0, rarity: Rarity = 'common') => ({ status, leverage: 3, upstream, rarity, sources })

describe('getCardView', () => {
  it('passes through the kind, tag, URL, sources, and card identity', () => {
    const view = getCardView(
      createTaskNode(
        createTaskData({
          itemKind: 'placeholder',
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
      kind: 'placeholder',
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
    expect(getCardView(createTaskNode(createTaskData({ itemKind: 'gate' })), createFacts('ready', 14, 'mythic'))).toMatchObject({
      upstream: 14,
      rarity: 'mythic',
    })
    const note = getCardView(createTaskNode(createTaskData({ itemKind: 'note' })), createFacts('done', 14, 'mythic'))

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

  it.each([
    ['SUCCESS', 'passing'],
    ['FAILURE', 'failing'],
    ['ERROR', 'failing'],
    ['PENDING', 'pending'],
    ['EXPECTED', 'pending'],
  ] as const)('maps %s checks to %s', (checks, expected) => {
    const taskNode = createTaskNode(createTaskData({ refs: [{ source: 'github', kind: 'pull', key: 'vocksel/orion#1', details: { checks } }] }))

    expect(getCardView(taskNode, createFacts()).checks).toBe(expected)
  })

  it('omits checks when the pull has no check state', () => {
    const taskNode = createTaskNode(createTaskData({ refs: [{ source: 'github', kind: 'pull', key: 'vocksel/orion#1', details: {} }] }))

    expect(getCardView(taskNode, createFacts()).checks).toBeUndefined()
    expect(getCardView(createTaskNode(createTaskData()), createFacts()).checks).toBeUndefined()
  })

  it('carries check progress and counts only while the pull request is open', () => {
    const details = { checks: 'FAILURE', checkProgress: 'running', checkCounts: { total: 8, finished: 3, failed: 1 } }
    const pull = (state: string) =>
      createTaskNode(createTaskData({ refs: [{ source: 'github', kind: 'pull', key: 'vocksel/orion#1', details: { ...details, state } }] }))

    expect(getCardView(pull('OPEN'), createFacts())).toMatchObject({ checkProgress: 'running', checkCounts: details.checkCounts })
    expect(getCardView(pull('MERGED'), createFacts())).not.toHaveProperty('checkCounts')
    expect(getCardView(pull('MERGED'), createFacts())).not.toHaveProperty('checkProgress')
  })

  it('opens a pull request card from its primary ref, not from another GitHub badge', () => {
    const pullUrl = 'https://github.com/vocksel/orion/pull/153'
    const issueUrl = 'https://github.com/vocksel/orion/issues/187'
    const taskNode = createTaskNode(
      createTaskData({
        itemKind: 'pr',
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

    expect(getCardView(taskNode, { ...createFacts(), sources: badges })).toMatchObject({ url: pullUrl, pullRequestUrl: pullUrl })
  })

  it('does not open a pull request card when its primary ref is not on GitHub', () => {
    const taskNode = createTaskNode(
      createTaskData({ itemKind: 'pr', refs: [{ source: 'jira', kind: 'issue', key: 'ORN-12', url: 'https://jira.example.com/browse/ORN-12' }] }),
    )

    expect(getCardView(taskNode, createFacts())).not.toHaveProperty('pullRequestUrl')
  })

  it('offers a merge while GitHub would merge the pull request and the card is still in play', () => {
    const url = 'https://github.com/vocksel/orion/pull/1'
    const details = { state: 'OPEN', checks: 'SUCCESS', mergeState: 'CLEAN', head: 'abc123' }
    const taskNode = createTaskNode(createTaskData({ refs: [{ source: 'github', kind: 'pull', key: 'vocksel/orion#1', url, details }] }))

    expect(getCardView(taskNode, createFacts('review'))).toMatchObject({
      readiness: 'mergeable',
      readyToMerge: true,
      statusLabel: 'Ready to merge',
      merge: { url, head: 'abc123' },
    })
    expect(getCardView(taskNode, createFacts('blocked'))).toMatchObject({ readiness: 'mergeable', statusLabel: 'Blocked' })
    expect(getCardView(taskNode, createFacts('blocked'))).not.toHaveProperty('readyToMerge')
    expect(getCardView(taskNode, createFacts('blocked'))).not.toHaveProperty('merge')
  })

  it('leaves a snoozed job out of whether the checks are failing', () => {
    const node = createTaskNode(
      createTaskData({
        itemKind: 'pr',
        refs: [
          {
            source: 'github',
            kind: 'pull',
            key: 'vocksel/orion#341',
            url: 'https://github.com/vocksel/orion/pull/341',
            details: {
              state: 'OPEN',
              draft: false,
              title: 'Title',
              url: 'https://github.com/vocksel/orion/pull/341',
              author: 'vocksel',
              mine: true,
              requestedFromYou: false,
              updatedAt: '2026-10-13T00:00:00Z',
              additions: 1,
              deletions: 1,
              checkedAt: '2026-10-13T00:00:00Z',
              checks: 'FAILURE',
              checkCounts: { total: 3, finished: 3, failed: 1 },
              failedChecks: [{ name: 'docs' }],
            },
          },
        ],
      }),
    )
    const snoozes = [{ repo: 'vocksel/orion', name: 'docs', at: '2026-10-13T00:00:00Z' }]

    expect(getCardView(node, createFacts('review')).readiness).toBe('failing')
    expect(getCardView(node, { ...createFacts('review'), snoozes }).readiness).toBe('passing')
  })
})
