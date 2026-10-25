import { describe, expect, it } from 'vitest'
import { clipRect, describeCard, pickPerch, SWITCH_MARGIN, type PerchTarget } from './companion'

const target = (id: string, left: number, top: number, size = 100): PerchTarget => ({
  id,
  rect: { left, top, right: left + size, bottom: top + size },
})

describe('describeCard', () => {
  it.each([
    ['ready', 'excited', 'Ready'],
    ['active', '', 'In progress'],
    ['review', 'curious', 'In review'],
    ['blocked', 'worried', 'Blocked'],
    ['deferred', '', 'Deferred'],
    ['done', 'happy', 'Done'],
  ] as const)('reads %s cards as %s', (status, mood, text) => {
    expect(describeCard(status)).toEqual({ text, status, mood })
  })

  it('winks at cards waiting on you', () => {
    expect(describeCard('active', 'you')).toEqual({ text: 'Your move', status: 'active', mood: 'wink' })
  })

  it('side-eyes cards waiting on a review', () => {
    expect(describeCard('active', 'review')).toMatchObject({ status: 'review', mood: 'curious' })
  })

  it('celebrates done cards whoever had them', () => {
    expect(describeCard('done', 'you').mood).toBe('happy')
  })
})

describe('clipRect', () => {
  it('trims a rectangle to the view', () => {
    expect(clipRect({ left: -50, top: 20, right: 100, bottom: 600 }, 400, 300)).toEqual({ left: 0, top: 20, right: 100, bottom: 300 })
  })

  it('drops a rectangle that barely shows', () => {
    expect(clipRect({ left: 390, top: 20, right: 500, bottom: 200 }, 400, 300)).toBeNull()
  })
})

describe('pickPerch', () => {
  const targets = [target('left', 0, 0), target('right', 300, 0)]

  it('perches on the target nearest the pointer', () => {
    expect(pickPerch(targets, 120, 50, null)).toBe('left')
    expect(pickPerch(targets, 280, 50, null)).toBe('right')
  })

  it('stays put until a neighbor is clearly closer', () => {
    expect(pickPerch(targets, 220, 50, 'left')).toBe('left')
    expect(pickPerch(targets, 200 + SWITCH_MARGIN, 50, 'left')).toBe('right')
  })

  it('moves on when its perch leaves the view', () => {
    expect(pickPerch([target('right', 300, 0)], 0, 0, 'left')).toBe('right')
  })

  it('has nowhere to perch on an empty view', () => {
    expect(pickPerch([], 0, 0, 'left')).toBeNull()
  })
})
