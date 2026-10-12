import { describe, expect, it } from 'vitest'
import { getCardArt } from './cardArt'

describe('getCardArt', () => {
  it('reuses deterministic art for the same seed and kind', () => {
    const first = getCardArt('card-42', 'step')

    expect(getCardArt('card-42', 'step')).toBe(first)
    expect(first.markup).toContain('<g')
  })

  it('varies the art with the seed and kind', () => {
    expect(getCardArt('card-42', 'step').markup).not.toBe(getCardArt('card-43', 'step').markup)
    expect(getCardArt('card-42', 'step')).not.toEqual(getCardArt('card-42', 'gate'))
  })

  it.each(['placeholder', 'pr'] as const)('makes twenty %s cards visibly distinct', (kind) => {
    const art = Array.from({ length: 20 }, (_, index) => getCardArt(`layout-${index}`, kind))

    expect(new Set(art.map(({ markup }) => markup)).size).toBeGreaterThanOrEqual(15)
    expect(new Set(art.map(({ palettePick }) => palettePick)).size).toBeGreaterThan(1)
    expect(new Set(art.map(({ hueShift }) => hueShift)).size).toBeGreaterThan(10)
  })
})
