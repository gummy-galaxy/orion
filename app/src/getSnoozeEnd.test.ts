import { expect, test } from 'vitest'
import { getSnoozeEnd } from './getSnoozeEnd'

const NOW = Date.parse('2026-10-13T12:00:00Z')

test('a timed snooze ends that long from now', () => {
  expect(getSnoozeEnd('hour', NOW)).toBe('2026-10-13T13:00:00.000Z')
  expect(getSnoozeEnd('week', NOW)).toBe('2026-10-20T12:00:00.000Z')
})

test('a snooze until the job passes has no end time', () => {
  expect(getSnoozeEnd('pass', NOW)).toBeUndefined()
})
