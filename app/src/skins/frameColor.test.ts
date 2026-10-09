import { describe, expect, it } from 'vitest'
import { getCardInks, INK } from './frameColor'

describe('getCardInks', () => {
  it('keeps a repository pair stable across card kinds', () => {
    expect(getCardInks('vocksel/orion', 'step')).toEqual(getCardInks('vocksel/orion', 'pr'))
    expect(getCardInks('vocksel/orion', 'pr')[0]).not.toBe(getCardInks('vocksel/orion', 'pr')[1])
  })

  it('uses the full repository name', () => {
    const pairs = Array.from({ length: 30 }, (_, index) => getCardInks(`owner-${index}/orion`, 'pr').join(','))

    expect(new Set(pairs).size).toBeGreaterThan(10)
  })

  it('uses fixed inks for gates and cards without repositories', () => {
    expect(getCardInks(undefined, 'gate')).toEqual([INK.gold, INK.pink])
    expect(getCardInks('vocksel/orion', 'gate')).toEqual([INK.gold, INK.pink])
    expect(getCardInks(undefined, 'step')).toEqual([INK.teal, INK.violet])
  })
})
