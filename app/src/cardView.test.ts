import { describe, expect, it } from 'vitest'
import { getCardView } from './cardView'
import type { SourceRef } from './derive'
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
const createFacts = (status: ViewStatus = 'ready', upstream = 0) => ({ status, leverage: 3, upstream, sources })

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

  it('derives rarity for work and leaves it absent for notes', () => {
    expect(getCardView(createTaskNode(createTaskData({ itemKind: 'gate' })), createFacts('ready', 14))).toMatchObject({
      upstream: 14,
      rarity: 'mythic',
    })
    const note = getCardView(createTaskNode(createTaskData({ itemKind: 'note' })), createFacts('done', 14))

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
})
