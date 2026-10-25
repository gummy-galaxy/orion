import { describe, expect, it } from 'vitest'
import { parseDurationMs, readDurationMs } from './readDurationMs'

describe('parseDurationMs', () => {
  it('reads milliseconds and seconds', () => {
    expect(parseDurationMs('420ms')).toBe(420)
    expect(parseDurationMs(' 0.8s ')).toBe(800)
  })

  it('refuses anything that is not a plain time', () => {
    expect(parseDurationMs('')).toBeUndefined()
    expect(parseDurationMs('var(--motion-duration-fade)')).toBeUndefined()
    expect(parseDurationMs('light-dark(200ms, 300ms)')).toBeUndefined()
  })
})

describe('readDurationMs', () => {
  it('falls back without a page', () => {
    expect(readDurationMs('--motion-duration-clear', 420)).toBe(420)
  })
})
