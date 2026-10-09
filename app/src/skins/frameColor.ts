import type { CardView } from '../cardView'

export function hashText(value: string): number {
  let hash = 2166136261

  for (let index = 0; index < value.length; index++) {
    hash ^= value.charCodeAt(index)
    hash = Math.imul(hash, 16777619)
  }

  return hash >>> 0
}

export function getFramePalette(repo: CardView['repo'], kind: CardView['kind']): number {
  return hashText(repo || kind) % 6
}
