import { describe, expect, it } from 'vitest'
import { isTrackpadScroll } from './scrolling'

const wheel = (fields: { deltaX?: number; deltaY?: number; deltaMode?: number; wheelDeltaY?: number }) =>
  ({ deltaX: 0, deltaY: 0, deltaMode: 0, ...fields }) as WheelEvent

describe('isTrackpadScroll', () => {
  it('recognizes trackpad scrolls by their legacy delta', () => {
    expect(isTrackpadScroll(wheel({ deltaY: 3, wheelDeltaY: -9 }))).toBe(true)
    expect(isTrackpadScroll(wheel({ deltaY: -1.5, wheelDeltaY: 4 }))).toBe(true)
  })

  it('treats wheel notches as a mouse', () => {
    expect(isTrackpadScroll(wheel({ deltaY: 4.000244140625, wheelDeltaY: -120 }))).toBe(false)
    expect(isTrackpadScroll(wheel({ deltaY: 100, wheelDeltaY: -120 }))).toBe(false)
    expect(isTrackpadScroll(wheel({ deltaY: 3, deltaMode: 1 }))).toBe(false)
  })

  it('treats sideways movement as a trackpad', () => {
    expect(isTrackpadScroll(wheel({ deltaX: 2, deltaY: 100, wheelDeltaY: -120 }))).toBe(true)
  })
})
