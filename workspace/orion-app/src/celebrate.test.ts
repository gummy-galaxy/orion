import { describe, expect, it } from 'vitest'
import { CHAIN_BEATS_MS, CHAIN_STEP_MS, chainDelay, chainFinale, chainPulses, closesOut, timeChain } from './celebrate'
import type { AppNode, Link, Status, TaskData } from './model'

const task = (id: string, status: Status = 'todo', extra: Partial<TaskData> = {}, type?: string): AppNode => ({
  id,
  type: 'task',
  position: { x: 0, y: 0 },
  data: { kind: 'task', label: id, ...(type ? { type } : {}), status, ...extra },
})
const link = (from: string, to: string, kind: Link['kind'] = 'blocks'): Link => ({
  id: `${from}>${to}`,
  from,
  to,
  kind,
})

describe('chainDelay', () => {
  it('times the click and the first three hops as climbing beats, then spaces later hops evenly', () => {
    const delays = Array.from({ length: 7 }, (_, hops) => chainDelay(hops))

    expect(delays.slice(0, 4)).toEqual(CHAIN_BEATS_MS)
    expect(delays.slice(4)).toEqual([1250 + CHAIN_STEP_MS, 1250 + 2 * CHAIN_STEP_MS, 1250 + 3 * CHAIN_STEP_MS])
  })

  it('spaces hops past the finale by the step it is given, leaving the beats alone', () => {
    expect(chainDelay(3, 100)).toBe(1250)
    expect(chainDelay(4, 100)).toBe(1350)
  })

  it('caps the delay so a long chain still finishes in about three seconds', () => {
    expect(chainDelay(19)).toBe(1250 + 5 * CHAIN_STEP_MS)
  })
})

describe('timeChain', () => {
  const answer = {
    closed: [
      { id: 'a', hops: 0 },
      { id: 'b', hops: 1 },
      { id: 'd', hops: 3 },
    ],
    passed: [{ id: 'c', hops: 2 }],
  }

  it('times each card from the answer by the beat its hops from the click land on', () => {
    const { beats, closed } = timeChain(answer, 20)

    expect([...closed]).toEqual([
      ['a', 130],
      ['b', 480],
      ['d', 1230],
    ])
    expect(beats.get('c')).toBe(830)
  })

  it('pushes the cards after the clicked one back together when the answer comes late, keeping their rhythm', () => {
    const { beats, closed } = timeChain(answer, 700)

    expect([...closed]).toEqual([
      ['a', -550],
      ['b', 0],
      ['d', 750],
    ])
    expect(beats.get('c')).toBe(350)
  })
})

describe('chainPulses', () => {
  it('runs a pulse along each blocking link from the earlier beat to the later one, over the gap between them', () => {
    const beats = new Map([
      ['up', 500],
      ['start', 150],
      ['down', 500],
    ])
    const links = [link('up', 'start'), link('start', 'down')]

    expect([...chainPulses(beats, links, 500)]).toEqual([
      ['up>start', { delayMs: 150, durationMs: 350, reverse: true }],
      ['start>down', { delayMs: 150, durationMs: 350, reverse: false }],
    ])
  })

  it('skips related links and links between cards on the same beat', () => {
    const beats = new Map([
      ['a', 150],
      ['b', 500],
      ['c', 500],
    ])
    const links = [link('a', 'b', 'related'), link('b', 'c')]

    expect(chainPulses(beats, links, 500).size).toBe(0)
  })

  it('crosses a card closed out before, and stops at the last card that clears', () => {
    const links = [link('a', 'b'), link('b', 'c'), link('c', 'd')]
    const { beats, closed } = timeChain(
      {
        closed: [
          { id: 'a', hops: 0 },
          { id: 'c', hops: 2 },
        ],
        passed: [
          { id: 'b', hops: 1 },
          { id: 'd', hops: 3 },
        ],
      },
      0,
    )

    const pulses = chainPulses(beats, links, Math.max(...closed.values()))

    expect([...pulses.keys()]).toEqual(['a>b', 'b>c'])
  })
})

describe('chainFinale', () => {
  it('picks every card on the last beat, with that beat', () => {
    const delays = new Map([
      ['a', 150],
      ['b', 500],
      ['c', 500],
    ])

    expect([...chainFinale(delays)]).toEqual([
      ['b', 500],
      ['c', 500],
    ])
  })

  it('gives a lone card the finale, so closing out one card still resolves', () => {
    expect([...chainFinale(new Map([['a', 150]]))]).toEqual([['a', 150]])
  })
})

// The card menu's Mark done and the inspector's Done both save `{ status: 'done' }` through the same patch.
describe('finishing a card in the app', () => {
  it('closes it out at once from the card menu', () => {
    const data = task('a', 'active').data as TaskData
    const patch = { status: 'done' } as const

    expect(closesOut(data, patch)).toBe(true)
  })

  it('closes it out at once from the inspector', () => {
    const data = task('a', 'review').data as TaskData
    const patch: Partial<TaskData> = { status: 'done' }

    expect(closesOut(data, patch)).toBe(true)
  })

  it('leaves cards finished outside the app waiting', () => {
    const data = task('a', 'done', { celebrate: true }).data as TaskData

    expect(closesOut(data, { status: 'done' })).toBe(false)
    expect(closesOut(data, { label: 'Renamed' })).toBe(false)
  })

  it('does not land a stamp on notes or components', () => {
    expect(closesOut(task('n', 'todo', {}, 'note').data as TaskData, { status: 'done' })).toBe(false)
    expect(closesOut(task('c', 'todo', {}, 'component').data as TaskData, { status: 'done' })).toBe(false)
  })
})
