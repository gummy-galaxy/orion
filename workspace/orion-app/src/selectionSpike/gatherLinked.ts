import type { SpikeLink } from './types'

/**
 * The cards within `hops` links of `origins`. A card in `leftBehind` isn't gathered, and
 * nothing is reached through it, so leaving a bridge behind also leaves what lies past it.
 */
export function gatherLinked(links: SpikeLink[], origins: Iterable<string>, hops: number, leftBehind: ReadonlySet<string> = new Set()) {
  const gathered = new Set<string>()
  let frontier = [...origins].filter((id) => !leftBehind.has(id))

  frontier.forEach((id) => gathered.add(id))

  for (let hop = 0; hop < hops && frontier.length > 0; hop++) {
    const next: string[] = []

    for (const link of links) {
      for (const [from, to] of [
        [link.from, link.to],
        [link.to, link.from],
      ]) {
        if (frontier.includes(from) && !gathered.has(to) && !leftBehind.has(to)) {
          gathered.add(to)
          next.push(to)
        }
      }
    }

    frontier = next
  }

  return gathered
}
