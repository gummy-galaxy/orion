export type Rarity = 'common' | 'uncommon' | 'rare' | 'mythic'

export const UNCOMMON_UPSTREAM = 4
export const RARE_UPSTREAM = 8
export const MYTHIC_UPSTREAM = 14

export function getRarity(upstream: number): Rarity {
  if (upstream >= MYTHIC_UPSTREAM) return 'mythic'

  if (upstream >= RARE_UPSTREAM) return 'rare'

  if (upstream >= UNCOMMON_UPSTREAM) return 'uncommon'

  return 'common'
}

export function describeRarity(rarity: Rarity, upstream: number): string {
  return `${rarity[0].toUpperCase()}${rarity.slice(1)}: ${upstream} ${upstream === 1 ? 'card feeds' : 'cards feed'} into this`
}
