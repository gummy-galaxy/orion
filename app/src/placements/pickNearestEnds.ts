type Point = { x: number; y: number }

/**
 * Where a link between two cards is drawn when either appears more than once: the pair of appearances closest to each
 * other, so each link draws one line per canvas. Returns null when either end has nowhere to draw.
 */
export function pickNearestEnds(sources: string[], targets: string[], centerOf: (id: string) => Point | undefined) {
  let best: { source: string; target: string } | null = null
  let bestDistance = Infinity

  for (const source of sources) {
    const from = centerOf(source)

    for (const target of targets) {
      const to = centerOf(target)
      const distance = from && to ? Math.hypot(from.x - to.x, from.y - to.y) : Infinity

      if (!best || distance < bestDistance) {
        best = { source, target }
        bestDistance = distance
      }
    }
  }

  return best
}
