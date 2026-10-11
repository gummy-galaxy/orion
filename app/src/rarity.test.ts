import { describe, expect, it } from 'vitest'
import { describeRarity, getRarity, MYTHIC_UPSTREAM, RARE_UPSTREAM, UNCOMMON_UPSTREAM } from './rarity'

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

  it('lifts P0 cards two tiers and P1 cards one, up to mythic', () => {
    expect(getRarity(0, 0)).toBe('rare')
    expect(getRarity(UNCOMMON_UPSTREAM, 0)).toBe('mythic')
    expect(getRarity(MYTHIC_UPSTREAM, 0)).toBe('mythic')
    expect(getRarity(0, 1)).toBe('uncommon')
    expect(getRarity(RARE_UPSTREAM, 1)).toBe('mythic')
    expect(getRarity(0, 2)).toBe('common')
    expect(getRarity(0, 3)).toBe('common')
  })
})

describe('describeRarity', () => {
  it('names the tier, the work feeding in, and any priority that raised it', () => {
    expect(describeRarity('uncommon', 4)).toBe('Uncommon: 4 cards feed into this')
    expect(describeRarity('rare', 1, 1)).toBe('Rare: 1 card feeds into this, raised by P1')
    expect(describeRarity('common', 0, 2)).toBe('Common: 0 cards feed into this')
  })
})
