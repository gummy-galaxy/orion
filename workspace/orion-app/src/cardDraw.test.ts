import { describe, expect, it } from 'vitest'
import { CardDraw, DRAW_BATCH, DRAW_MARGIN_PX, drawViewOf, type DrawCard } from './cardDraw'

const card = (id: string, x: number, y: number): DrawCard => ({ id, x, y, width: 216, height: 72 })

/** A 1000 x 800 screen at zoom 1, panned so flow point (0, 0) is the top left corner. */
const origin = drawViewOf([0, 0, 1], 1000, 800)!

describe('drawViewOf', () => {
  it('is null until the canvas has a size', () => {
    expect(drawViewOf([0, 0, 1], 0, 800)).toBeNull()
    expect(drawViewOf([0, 0, 1], 1000, 0)).toBeNull()
  })

  it('pads the visible box by the margin in flow units', () => {
    const zoomed = drawViewOf([-200, 0, 2], 1000, 800)!

    expect(zoomed.box.x).toBeCloseTo(100 - DRAW_MARGIN_PX / 2)
    expect(zoomed.box.width).toBeCloseTo(500 + DRAW_MARGIN_PX)
    expect(zoomed.center).toEqual({ x: 350, y: 200 })
  })
})

describe('CardDraw', () => {
  it('only wants cards that touch the view with its margin', () => {
    const draw = new CardDraw()
    const near = card('near', 100, 100)
    const far = card('far', 5000, 5000)

    draw.update([near, far], origin)

    while (draw.pending) draw.step()

    expect([...draw.drawn]).toEqual(['near'])
  })

  it('draws the cards nearest the center first, a batch per step', () => {
    const draw = new CardDraw()
    const cards = Array.from({ length: DRAW_BATCH + 10 }, (_, index) => card(`c${index}`, index * 2, 0))

    draw.update(cards, origin)
    draw.step()

    // The view's center is at x 500, so the cards nearest it are the rightmost ones.
    expect(draw.drawn.size).toBe(DRAW_BATCH)
    expect(draw.drawn.has(`c${DRAW_BATCH + 9}`)).toBe(true)
    expect(draw.drawn.has('c0')).toBe(false)

    draw.step()

    expect(draw.drawn.size).toBe(DRAW_BATCH + 10)
  })

  it('reports a change when a drawn card leaves the margin, and drops it at once', () => {
    const draw = new CardDraw()
    const near = card('near', 100, 100)

    draw.update([near], origin)

    while (draw.pending) draw.step()

    expect(draw.update([near], drawViewOf([-10000, 0, 1], 1000, 800))).toBe(true)
    expect(draw.drawn.size).toBe(0)
  })

  it('drops cards that were removed from the list', () => {
    const draw = new CardDraw()

    draw.update([card('a', 0, 0), card('b', 10, 10)], origin)

    while (draw.pending) draw.step()

    expect(draw.update([card('a', 0, 0)], origin)).toBe(true)
    expect([...draw.drawn]).toEqual(['a'])
  })

  it('re-sorts what is still queued once the view settles', () => {
    const draw = new CardDraw()
    // Three batches of cards all sit inside both views, so the first batch comes from the right and the rest wait.
    const cards = Array.from({ length: DRAW_BATCH * 3 }, (_, index) => card(`c${index}`, index * 10, 0))
    const right = drawViewOf([1000, 0, 0.1], 10000, 800)!
    const left = drawViewOf([5000, 0, 0.1], 10000, 800)!

    draw.update(cards, right)
    draw.step()

    // Moving left without settling keeps the old queue, so the next batch is still the rightmost cards left.
    draw.update(cards, left)
    draw.step()
    expect(draw.drawn.has('c0')).toBe(false)

    // Once settled, the queue follows the view, so the leftmost cards come next.
    draw.update(cards, left)
    draw.settle()
    draw.step()

    expect(draw.drawn.has('c0')).toBe(true)
  })

  it('does not draw anything before the canvas has a size', () => {
    const draw = new CardDraw()

    draw.update([card('a', 0, 0)], null)

    expect(draw.pending).toBe(false)
    expect(draw.drawn.size).toBe(0)
  })
})
