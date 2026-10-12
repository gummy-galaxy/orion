import { describe, expect, it } from 'vitest'
import { getRarity, MYTHIC_UPSTREAM, RARE_UPSTREAM, UNCOMMON_UPSTREAM } from './rarity'

describe('getRarity', () => {
  it.each([
    [0, 'common'],
    [UNCOMMON_UPSTREAM - 1, 'common'],
    [UNCOMMON_UPSTREAM, 'uncommon'],
    [RARE_UPSTREAM - 1, 'uncommon'],
    [RARE_UPSTREAM, 'rare'],
    [MYTHIC_UPSTREAM - 1, 'rare'],
    [MYTHIC_UPSTREAM, 'mythic'],
  ] as const)('maps %i upstream cards to %s', (upstream, rarity) => {
    expect(getRarity(upstream)).toBe(rarity)
  })
})
