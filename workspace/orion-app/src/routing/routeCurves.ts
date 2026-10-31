import { curvePath } from './curvePath'
import { sourcePort, targetPort } from './ports'
import type { Routing, Scene } from './types'

/** The baseline: every link is React Flow's curve between its two handles, with no idea what's in the way. */
export function routeCurves(scene: Scene): Routing {
  const cards = new Map(scene.cards.map((card) => [card.id, card]))
  const lines = scene.links.map((link) => ({
    id: link.id,
    source: link.from,
    target: link.to,
    d: curvePath(sourcePort(cards.get(link.from)!), targetPort(cards.get(link.to)!)),
    arrow: true,
  }))

  return { lines, fallbacks: 0 }
}
