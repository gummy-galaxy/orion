import { expect, test } from 'vitest'
import { summarizeDurations } from './summarizeDurations'

test('durations summarize as their median, 95th percentile, and slowest', () => {
  const samples = Array.from({ length: 100 }, (_, index) => 100 - index + 0.004)

  expect(summarizeDurations(samples)).toEqual({ count: 100, p50: 50, p95: 95, max: 100 })
  expect(samples[0]).toBe(100.004)
})

test('one sample is every percentile, and none is no summary', () => {
  expect(summarizeDurations([16.667])).toEqual({ count: 1, p50: 16.67, p95: 16.67, max: 16.67 })
  expect(summarizeDurations([])).toBeNull()
})
