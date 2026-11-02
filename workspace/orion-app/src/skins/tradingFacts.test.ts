import { describe, expect, it } from 'vitest'
import type { CardView } from '../cardView'
import { getTradingFacts } from './tradingFacts'

const NOW = Date.parse('2026-10-11T12:00:00Z')

const createView = (overrides: Partial<CardView> = {}): CardView => ({
  id: 'card',
  kind: 'pr',
  layout: 'card',
  fields: [],
  badges: [],
  title: 'Work',
  tag: 'vocksel/orion#1',
  url: null,
  status: 'review',
  statusLabel: 'In review',
  leverage: 0,
  upstream: 0,
  sources: [],
  artSeed: 'card',
  updatedAt: '2026-10-10T12:00:00Z',
  ...overrides,
})

describe('getTradingFacts', () => {
  it('shows nothing on top of a calm card', () => {
    expect(getTradingFacts(createView(), NOW)).toEqual({ locked: false, blockers: 0, unblocks: 0, hue: 0 })
  })

  it('picks the most urgent status badge', () => {
    expect(getTradingFacts(createView({ readiness: 'conflict', changesRequested: true }), NOW).statusBadge).toBe(
      'conflict',
    )
    expect(getTradingFacts(createView({ readiness: 'failing', changesRequested: true }), NOW).statusBadge).toBe(
      'failing',
    )
    expect(getTradingFacts(createView({ readiness: 'passing', changesRequested: true }), NOW).statusBadge).toBe(
      'changes',
    )
    expect(getTradingFacts(createView({ readiness: 'mergeable', readyToMerge: true }), NOW).statusBadge).toBe(
      'mergeable',
    )
  })

  it('marks pull requests with no change in two weeks stale', () => {
    expect(getTradingFacts(createView({ updatedAt: '2026-09-20T12:00:00Z' }), NOW).statusBadge).toBe('stale')
    expect(
      getTradingFacts(createView({ kind: 'step', updatedAt: '2026-09-20T12:00:00Z' }), NOW).statusBadge,
    ).toBeUndefined()
  })

  it('shows checks still running or queued as motion, not a status badge', () => {
    expect(getTradingFacts(createView({ readiness: 'running' }), NOW)).toMatchObject({ motion: 'running' })
    expect(getTradingFacts(createView({ readiness: 'waiting' }), NOW)).toMatchObject({ motion: 'queued' })
    expect(getTradingFacts(createView({ readiness: 'running' }), NOW).statusBadge).toBeUndefined()
  })

  it('keeps checks moving beside the failing status badge until the rest finish', () => {
    expect(getTradingFacts(createView({ readiness: 'failing', checkProgress: 'running' }), NOW)).toMatchObject({
      statusBadge: 'failing',
      motion: 'running',
    })
    expect(getTradingFacts(createView({ readiness: 'failing' }), NOW).motion).toBeUndefined()
  })

  it('shows priority and size only when a source sets them', () => {
    expect(getTradingFacts(createView({ leverage: 8 }), NOW).priority).toBeUndefined()
    expect(getTradingFacts(createView({ priority: 0, size: 'L' }), NOW)).toMatchObject({ priority: 0, size: 'L' })
  })

  it('drops status badges and motion from finished and parked work', () => {
    const facts = getTradingFacts(createView({ status: 'done', readiness: 'failing' }), NOW)

    expect(facts.statusBadge).toBeUndefined()
    expect(facts.motion).toBeUndefined()
  })

  it('locks blocked cards and keeps their counts', () => {
    expect(getTradingFacts(createView({ status: 'blocked', blockers: 2, unblocks: 1 }), NOW)).toMatchObject({
      locked: true,
      blockers: 2,
      unblocks: 1,
    })
  })
})
