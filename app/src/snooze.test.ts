import { describe, expect, it } from 'vitest'
import { localDateValue, snoozeUntil, toStoredTime } from './snooze'

// 2026-10-10 is a Saturday.
const SATURDAY = new Date(2026, 9, 10, 15, 30)

describe('snoozeUntil', () => {
  it('wakes later today four hours from now', () => {
    expect(snoozeUntil('later', new Date('2026-10-10T15:00:00Z'))).toBe('2026-10-10T19:00:00Z')
  })

  it('wakes tomorrow at the start of the next local day', () => {
    expect(snoozeUntil('tomorrow', SATURDAY)).toBe(toStoredTime(new Date(2026, 9, 11)))
  })

  it('wakes next week at the start of the coming Monday', () => {
    expect(snoozeUntil('nextWeek', SATURDAY)).toBe(toStoredTime(new Date(2026, 9, 12)))
  })

  it('wakes on a Monday next week rather than today', () => {
    expect(snoozeUntil('nextWeek', new Date(2026, 9, 12, 9))).toBe(toStoredTime(new Date(2026, 9, 19)))
  })

  it('wakes a picked date at the start of that local day', () => {
    expect(snoozeUntil({ date: '2026-11-02' }, SATURDAY)).toBe(toStoredTime(new Date(2026, 10, 2)))
  })
})

describe('localDateValue', () => {
  it('formats a local date for date inputs', () => {
    expect(localDateValue(new Date(2026, 0, 5, 23))).toBe('2026-01-05')
  })
})
