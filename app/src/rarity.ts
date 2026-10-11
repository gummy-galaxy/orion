import type { Priority } from './cardView'

export type Rarity = 'common' | 'uncommon' | 'rare' | 'mythic'

export const RARITIES: Rarity[] = ['common', 'uncommon', 'rare', 'mythic']

export const UNCOMMON_UPSTREAM = 4
export const RARE_UPSTREAM = 8
export const MYTHIC_UPSTREAM = 14

/** How many tiers a source's priority raises a card: P0 two, P1 one. */
const PRIORITY_BOOST: Record<Priority, number> = { 0: 2, 1: 1, 2: 0, 3: 0 }

function getUpstreamTier(upstream: number): number {
  if (upstream >= MYTHIC_UPSTREAM) return 3

  if (upstream >= RARE_UPSTREAM) return 2

  if (upstream >= UNCOMMON_UPSTREAM) return 1

  return 0
}

/** Rarity climbs with the work that feeds into a card, and a high priority from a source lifts it further. */
export function getRarity(upstream: number, priority?: Priority): Rarity {
  const boost = priority === undefined ? 0 : PRIORITY_BOOST[priority]

  return RARITIES[Math.min(getUpstreamTier(upstream) + boost, RARITIES.length - 1)]
}

export function describeRarity(rarity: Rarity, upstream: number, priority?: Priority): string {
  const feeds = `${upstream} ${upstream === 1 ? 'card feeds' : 'cards feed'} into this`
  const raised = priority !== undefined && PRIORITY_BOOST[priority] > 0 ? `, raised by P${priority}` : ''

  return `${rarity[0].toUpperCase()}${rarity.slice(1)}: ${feeds}${raised}`
}
