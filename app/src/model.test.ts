import { describe, expect, it } from 'vitest'
import { reviewStage, type GithubState } from './model'

const pull = (extra: Partial<GithubState>): GithubState => ({
  state: 'OPEN',
  draft: false,
  title: 'Title',
  url: 'u',
  author: 'vocksel',
  mine: true,
  requestedFromYou: false,
  updatedAt: '2026-10-04T00:00:00Z',
  additions: 1,
  deletions: 1,
  checkedAt: '2026-10-04T00:00:00Z',
  ...extra,
})

describe('reviewStage', () => {
  it('tells approved, merge blocked, and owner pending apart', () => {
    expect(reviewStage(pull({ reviewDecision: 'APPROVED', mergeStateStatus: 'CLEAN' }))).toBe('Approved')
    expect(reviewStage(pull({ reviewDecision: 'APPROVED', mergeStateStatus: 'BLOCKED' }))).toBe('Merge blocked')
    expect(reviewStage(pull({ reviewDecision: 'REVIEW_REQUIRED', approvers: ['mneff'] }))).toBe('Owner pending')
    expect(reviewStage(pull({ reviewDecision: 'REVIEW_REQUIRED' }))).toBe(null)
    expect(reviewStage(pull({ draft: true, approvers: ['mneff'] }))).toBe(null)
    expect(reviewStage(pull({ state: 'MERGED', reviewDecision: 'APPROVED' }))).toBe(null)
  })
})
