import { describe, expect, it } from 'vitest'
import { offsetsFrom, placeStickers, pressedStickers, type Sticker } from './sticker'
import type { AppNode } from './model'

const sticker = (id: string, x: number, y: number, on?: string): Sticker => ({ id, kind: '⭐', x, y, tilt: 0, on })

describe('picking stickers', () => {
  it('picks a sticker alone on a plain press', () => {
    expect([...pressedStickers(new Set(['a']), 'b', false)]).toEqual(['b'])
  })

  it('keeps the whole pick on a plain press of a sticker already in it, so it can be dragged together', () => {
    const picked = new Set(['a', 'b'])

    expect(pressedStickers(picked, 'a', false)).toBe(picked)
  })

  it('adds an unpicked sticker with ⇧ or ⌘ and removes a picked one', () => {
    expect([...pressedStickers(new Set(['a']), 'b', true)]).toEqual(['a', 'b'])
    expect([...pressedStickers(new Set(['a', 'b']), 'a', true)]).toEqual(['b'])
  })

  it('leaves the picked set it was given alone', () => {
    const picked = new Set(['a'])

    pressedStickers(picked, 'b', true)

    expect([...picked]).toEqual(['a'])
  })
})

describe('moving picked stickers with an anchor', () => {
  it('keeps each loose sticker where it sits from the anchor', () => {
    const offsets = offsetsFrom({ x: 100, y: 100 }, [sticker('near', 130, 90), sticker('far', 40, 260)])

    expect(offsets.get('near')).toEqual({ x: 30, y: -10 })
    expect(offsets.get('far')).toEqual({ x: -60, y: 160 })
  })

  it('leaves out stickers on a card or group, which move with it already', () => {
    const offsets = offsetsFrom({ x: 0, y: 0 }, [sticker('on-card', 10, 10, 'card'), sticker('loose', 5, 5)])

    expect([...offsets.keys()]).toEqual(['loose'])
  })
})

describe('placing stickers', () => {
  const card = (id: string, x: number, y: number): AppNode => ({
    id,
    type: 'task',
    position: { x, y },
    data: { kind: 'task', label: id, itemKind: 'step', status: 'todo' },
  })

  it('leaves a loose sticker where it is', () => {
    const placed = placeStickers([sticker('loose', 40, 50)], new Map(), new Set())

    expect(placed).toEqual([sticker('loose', 40, 50)])
  })

  it('moves a sticker on a card to where the card is', () => {
    const nodes = new Map([['card', card('card', 300, 200)]])
    const placed = placeStickers([sticker('on-card', 10, 20, 'card')], nodes, new Set())

    expect(placed[0]).toMatchObject({ id: 'on-card', x: 310, y: 220 })
  })

  it('hides a sticker while its card is hidden, and drops one whose card is gone', () => {
    const nodes = new Map([['card', card('card', 0, 0)]])
    const stickers = [sticker('hidden', 1, 1, 'card'), sticker('gone', 1, 1, 'missing')]

    expect(placeStickers(stickers, nodes, new Set(['card']))).toEqual([])
  })
})
