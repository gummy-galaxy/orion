import { afterEach, describe, expect, it } from 'vitest'
import { DEFAULT_COMPACT_ZOOM, getCompactZoom, setCompactZoom, subscribeCompactZoom, zoomLevel } from './zoomLevel'

afterEach(() => setCompactZoom(DEFAULT_COMPACT_ZOOM))

describe('zoom level', () => {
  it('draws compact below the breakpoint and full at or above it', () => {
    expect(zoomLevel(0.06)).toBe('compact')
    expect(zoomLevel(DEFAULT_COMPACT_ZOOM - 0.01)).toBe('compact')
    expect(zoomLevel(DEFAULT_COMPACT_ZOOM)).toBe('full')
    expect(zoomLevel(1)).toBe('full')
  })

  it('moves the breakpoint when it is tuned', () => {
    setCompactZoom(0.5)
    expect(getCompactZoom()).toBe(0.5)
    expect(zoomLevel(0.4)).toBe('compact')
    expect(zoomLevel(0.6)).toBe('full')
  })

  it('ignores values that are not a positive number', () => {
    setCompactZoom(0.5)
    setCompactZoom(0)
    setCompactZoom(-1)
    setCompactZoom(Number.NaN)
    expect(getCompactZoom()).toBe(0.5)
  })

  it('tells listeners when the breakpoint moves until they unsubscribe', () => {
    let calls = 0
    const unsubscribe = subscribeCompactZoom(() => calls++)

    setCompactZoom(0.4)
    unsubscribe()
    setCompactZoom(0.5)
    expect(calls).toBe(1)
  })
})
