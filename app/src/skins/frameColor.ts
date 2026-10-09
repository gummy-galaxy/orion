import type { CardView } from '../cardView'

export const INK = {
  teal: '#18d6c0',
  blue: '#3b6cff',
  violet: '#b45cff',
  pink: '#ff8fa3',
  amber: '#ffb347',
  red: '#ff5e7e',
  gold: '#ffd166',
  magenta: '#d94dff',
} as const

const REPOSITORY_INKS = Object.values(INK)

export type InkPair = readonly [string, string]

export function hashText(value: string): number {
  let hash = 2166136261

  for (let index = 0; index < value.length; index++) {
    hash ^= value.charCodeAt(index)
    hash = Math.imul(hash, 16777619)
  }

  return hash >>> 0
}

export function getCardInks(repo: CardView['repo'], kind: CardView['kind']): InkPair {
  if (kind === 'gate') return [INK.gold, INK.pink]

  if (!repo) return [INK.teal, INK.violet]

  const hash = hashText(repo)
  const first = hash % REPOSITORY_INKS.length
  const second = (first + 1 + (Math.floor(hash / REPOSITORY_INKS.length) % (REPOSITORY_INKS.length - 1))) % REPOSITORY_INKS.length

  return [REPOSITORY_INKS[first], REPOSITORY_INKS[second]]
}
