import { describe, expect, it } from 'vitest'
import type { CardView } from '../cardView'
import { getSlotFacts } from './slotFacts'

const NOW = Date.parse('2026-10-11T12:00:00Z')

const createView = (overrides: Partial<CardView> = {}): CardView => ({
  id: 'card',
  kind: 'pr',
  title: 'Work',
  tag: 'vocksel/orion#1',
  url: null,
  status: 'review',
  statusLabel: 'In review',
  leverage: 0,
  sources: [],
  artSeed: 'card',
  updatedAt: '2026-10-10T12:00:00Z',
  ...overrides,
})

describe('getSlotFacts', () => {
  it('shows nothing on top of a calm card', () => {
    expect(getSlotFacts(createView(), NOW)).toEqual({ locked: false, blockers: 0, unblocks: 0, hue: 0 })
  })

  it('picks the most urgent sticker', () => {
    expect(getSlotFacts(createView({ readiness: 'conflict', changesRequested: true }), NOW).sticker).toBe('conflict')
    expect(getSlotFacts(createView({ readiness: 'failing', changesRequested: true }), NOW).sticker).toBe('failing')
    expect(getSlotFacts(createView({ readiness: 'passing', changesRequested: true }), NOW).sticker).toBe('changes')
    expect(getSlotFacts(createView({ readiness: 'mergeable', readyToMerge: true }), NOW).sticker).toBe('mergeable')
  })

  it('marks pull requests with no change in two weeks stale', () => {
    expect(getSlotFacts(createView({ updatedAt: '2026-09-20T12:00:00Z' }), NOW).sticker).toBe('stale')
    expect(getSlotFacts(createView({ kind: 'step', updatedAt: '2026-09-20T12:00:00Z' }), NOW).sticker).toBeUndefined()
  })

  it('shows checks still running or queued as motion, not a sticker', () => {
    expect(getSlotFacts(createView({ readiness: 'running' }), NOW)).toMatchObject({ motion: 'running' })
    expect(getSlotFacts(createView({ readiness: 'waiting' }), NOW)).toMatchObject({ motion: 'queued' })
    expect(getSlotFacts(createView({ readiness: 'running' }), NOW).sticker).toBeUndefined()
  })

  it('estimates priority from leverage until a source sets one', () => {
    expect(getSlotFacts(createView({ leverage: 8 }), NOW).priority).toEqual({ value: 1, estimated: true })
    expect(getSlotFacts(createView({ leverage: 3 }), NOW).priority).toEqual({ value: 2, estimated: true })
    expect(getSlotFacts(createView({ leverage: 2 }), NOW).priority).toBeUndefined()
    expect(getSlotFacts(createView({ leverage: 8, priority: 3 }), NOW).priority).toEqual({ value: 3, estimated: false })
  })

  it('quiets finished and parked work', () => {
    const facts = getSlotFacts(createView({ status: 'done', leverage: 8, readiness: 'failing' }), NOW)

    expect(facts.priority).toBeUndefined()
    expect(facts.sticker).toBeUndefined()
  })

  it('locks blocked cards and keeps their counts', () => {
    expect(getSlotFacts(createView({ status: 'blocked', blockers: 2, unblocks: 1 }), NOW)).toMatchObject({ locked: true, blockers: 2, unblocks: 1 })
  })
})
