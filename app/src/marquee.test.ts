import { describe, expect, it } from 'vitest'
import { MARQUEE_REACH, covers } from './marquee'

const card = { x0: 0, y0: 0, x1: 200, y1: 100 }

describe('selection box coverage', () => {
  it('picks up a box that reaches a quarter of the card on each side', () => {
    expect(covers(card, { x0: 150, y0: 70, x1: 400, y1: 300 }, MARQUEE_REACH)).toBe(true)
  })

  it('skips a box that only grazes the card', () => {
    expect(covers(card, { x0: 190, y0: 0, x1: 400, y1: 300 }, MARQUEE_REACH)).toBe(false)
  })

  it('needs the whole box for a group that is only picked up when fully inside', () => {
    expect(covers(card, { x0: -10, y0: -10, x1: 400, y1: 300 }, 1)).toBe(true)
    expect(covers(card, { x0: 50, y0: -10, x1: 400, y1: 300 }, 1)).toBe(false)
  })

  it('picks up a small sticker when the box reaches a quarter of it', () => {
    const sticker = { x0: 80, y0: 80, x1: 120, y1: 120 }

    expect(covers(sticker, { x0: 110, y0: 110, x1: 300, y1: 300 }, MARQUEE_REACH)).toBe(true)
    expect(covers(sticker, { x0: 118, y0: 118, x1: 300, y1: 300 }, MARQUEE_REACH)).toBe(false)
  })
})
