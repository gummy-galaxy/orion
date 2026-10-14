import { describe, expect, it } from 'vitest'
import { changeSnoozes, findSnooze, isSnoozedOn, readCheckSnoozes, repoOfPullKey, withSnoozes, type CheckSnooze } from './checkSnoozes'
import type { PullDetails } from './model'

const NOW = Date.parse('2026-10-13T12:00:00Z')

const failing = (overrides: Partial<PullDetails> = {}): PullDetails => ({
  state: 'OPEN',
  draft: true,
  title: 'Title',
  author: 'vocksel',
  mine: true,
  requestedFromYou: false,
  updatedAt: '2026-10-13T00:00:00Z',
  additions: 1,
  deletions: 1,
  checkedAt: '2026-10-13T00:00:00Z',
  checks: 'FAILURE',
  checkCounts: { total: 6, finished: 6, failed: 1 },
  failedChecks: [{ name: 'docs' }],
  ...overrides,
})

const docs = (overrides: Partial<CheckSnooze> = {}): CheckSnooze => ({
  repo: 'vocksel/orion',
  name: 'docs',
  at: '2026-10-13T00:00:00Z',
  ...overrides,
})

describe('check snoozes', () => {
  it('reads snoozes from settings and skips malformed entries', () => {
    expect(readCheckSnoozes({ checkSnoozes: [docs(), { repo: 'vocksel/orion' }, 'docs'] })).toEqual([docs()])
    expect(readCheckSnoozes(undefined)).toEqual([])
  })

  it('finds the repository a pull request key belongs to, with or without a host', () => {
    expect(repoOfPullKey('vocksel/orion#341')).toBe('vocksel/orion')
    expect(repoOfPullKey('github.example.com/Roblox/avatar#2')).toBe('Roblox/avatar')
    expect(repoOfPullKey('ABC-12')).toBeUndefined()
  })

  it('matches a job by repository, ignoring case, and by exact name', () => {
    expect(findSnooze([docs()], 'Vocksel/Orion', 'docs', NOW)).toBeDefined()
    expect(findSnooze([docs()], 'vocksel/orion', 'Docs', NOW)).toBeUndefined()
    expect(findSnooze([docs()], 'vocksel/hop', 'docs', NOW)).toBeUndefined()
  })

  it('ends a timed snooze at its time', () => {
    expect(isSnoozedOn([docs({ until: '2026-10-13T13:00:00Z' })], 'vocksel/orion', 'docs', 'card', NOW)).toBe(true)
    expect(isSnoozedOn([docs({ until: '2026-10-13T11:00:00Z' })], 'vocksel/orion', 'docs', 'card', NOW)).toBe(false)
  })

  it('stops hiding a job on a card once it has passed there', () => {
    const snoozes = [docs({ passed: ['passed-card'] })]

    expect(isSnoozedOn(snoozes, 'vocksel/orion', 'docs', 'passed-card', NOW)).toBe(false)
    expect(isSnoozedOn(snoozes, 'vocksel/orion', 'docs', 'other-card', NOW)).toBe(true)
  })

  it('reads as passing when the only failures are snoozed', () => {
    const details = withSnoozes(failing(), 'vocksel/orion', 'card', [docs()], NOW)

    expect(details.checks).toBe('SUCCESS')
    expect(details.checkCounts?.failed).toBe(0)
  })

  it('reads as running when snoozed failures leave jobs still running', () => {
    const details = withSnoozes(failing({ checkCounts: { total: 6, finished: 4, failed: 1 } }), 'vocksel/orion', 'card', [docs()], NOW)

    expect(details.checks).toBe('PENDING')
  })

  it('keeps failing while another job fails, with one fewer failure', () => {
    const details = withSnoozes(
      failing({ checkCounts: { total: 6, finished: 6, failed: 2 }, failedChecks: [{ name: 'docs' }, { name: 'test' }] }),
      'vocksel/orion',
      'card',
      [docs()],
      NOW,
    )

    expect(details.checks).toBe('FAILURE')
    expect(details.checkCounts?.failed).toBe(1)
  })

  it('leaves details alone without a matching snooze', () => {
    const details = failing()

    expect(withSnoozes(details, 'vocksel/orion', 'card', [], NOW)).toBe(details)
    expect(withSnoozes(details, 'vocksel/hop', 'card', [docs()], NOW)).toBe(details)
  })

  it("replaces a job's snooze when it is snoozed again, and ends a timed one after its length", () => {
    const passed = changeSnoozes([docs({ passed: ['card'] })], { repo: 'Vocksel/Orion', name: 'docs', snoozed: true, length: 'hour' }, NOW)

    expect(passed.until).toBe('2026-10-13T13:00:00.000Z')
    expect(passed.snoozes).toEqual([{ repo: 'Vocksel/Orion', name: 'docs', at: '2026-10-13T12:00:00.000Z', until: '2026-10-13T13:00:00.000Z' }])
    expect(changeSnoozes([docs()], { repo: 'vocksel/orion', name: 'docs', snoozed: false, length: 'pass' }, NOW).snoozes).toEqual([])
  })
})
