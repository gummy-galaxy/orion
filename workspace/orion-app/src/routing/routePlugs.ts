import { curvePath } from './curvePath'
import { sourcePort, targetPort } from './ports'
import { routeBundles } from './routeBundles'
import type { Point, RoutedLine, Routing, Scene } from './types'

export type PlugOptions = {
  /** Links longer than this, port to port, collapse into a stub and a plug at each end. */
  threshold: number
  /** Bundle the links that stay whole, instead of drawing each as a curve. */
  bundles?: boolean
}

/** How far a stub runs out from its card before it reaches the plug. */
// A stub and its plug fill the gap between two cards in a group, so plugs never sit on a neighbor.
export const STUB = 16
export const PLUG = { width: 40, height: 14 }
/** The most plugs on each side of a card. The last one stands for every link past it. */
const MAX_SLOTS = 4
const SLOT_STEP = 17
const INSET = 4
/** Room left between a card's port and its first plug, above for outgoing plugs and below for incoming ones. */
const PORT_GAP = 2

/** How many plugs fit between a card's port and its top or bottom edge. */
const slotsOf = (height: number) =>
  Math.min(MAX_SLOTS, Math.max(1, Math.floor((height / 2 - INSET - PORT_GAP + SLOT_STEP - PLUG.height) / SLOT_STEP)))

/**
 * Like a schematic's off-page connectors: links shorter than the threshold draw in full, and longer ones become a
 * short stub out of each card that fades into a plug, a small copy of the card at the other end. Outgoing plugs stack
 * up from the port on a card's right side and incoming ones down from the port on its left side, so a plug in the gap
 * between two cards never sits on the plug of the card across from it.
 */
export function routePlugs(scene: Scene, { threshold, bundles = false }: PlugOptions): Routing {
  const cards = new Map(scene.cards.map((card) => [card.id, card]))
  const near: Scene['links'] = []
  const outgoing = new Map<string, Scene['links']>()
  const incoming = new Map<string, Scene['links']>()

  for (const link of scene.links) {
    const from = sourcePort(cards.get(link.from)!)
    const to = targetPort(cards.get(link.to)!)

    if (Math.hypot(to.x - from.x, to.y - from.y) <= threshold) {
      near.push(link)
      continue
    }

    outgoing.set(link.from, [...(outgoing.get(link.from) ?? []), link])
    incoming.set(link.to, [...(incoming.get(link.to) ?? []), link])
  }

  const whole = bundles
    ? routeBundles({ ...scene, links: near })
    : {
        lines: near.map((link) => ({
          id: link.id,
          source: link.from,
          target: link.to,
          d: curvePath(sourcePort(cards.get(link.from)!), targetPort(cards.get(link.to)!)),
          arrow: true,
        })),
        fallbacks: 0,
      }
  const lines: RoutedLine[] = [...whole.lines]
  const stubbed = scene.links.length - near.length

  for (const [cardId, links] of outgoing) {
    const card = cards.get(cardId)!
    const port = sourcePort(card)
    const far = (link: Scene['links'][number]) => cards.get(link.to)!

    const slots = slotsOf(card.height)

    // Plugs follow the order of the cards they stand for, top to bottom, so the stack reads like the canvas does. The
    // stack grows up from the port, so the lowest far card comes first.
    links.sort((a, b) => far(b).y - far(a).y)

    for (let slot = 0; slot < Math.min(slots, links.length); slot++) {
      const rest = slot === slots - 1 ? links.slice(slot) : [links[slot]]
      const at = { x: port.x + STUB, y: port.y - PORT_GAP - PLUG.height - slot * SLOT_STEP }
      const attach = { x: at.x, y: at.y + PLUG.height / 2 }

      lines.push({
        id: `plug-out:${cardId}:${slot}`,
        source: cardId,
        target: rest[0].to,
        d: stub(port, attach),
        arrow: false,
        plug: { at, owner: cardId, port, side: 'out', card: rest[0].to, links: rest.map((link) => link.id), more: rest.length - 1 },
      })
    }
  }

  for (const [cardId, links] of incoming) {
    const card = cards.get(cardId)!
    const port = targetPort(card)
    const far = (link: Scene['links'][number]) => cards.get(link.from)!

    const slots = slotsOf(card.height)

    links.sort((a, b) => far(a).y - far(b).y)

    for (let slot = 0; slot < Math.min(slots, links.length); slot++) {
      const rest = slot === slots - 1 ? links.slice(slot) : [links[slot]]
      const at = { x: port.x - STUB - PLUG.width, y: port.y + PORT_GAP + slot * SLOT_STEP }
      const attach = { x: at.x + PLUG.width, y: at.y + PLUG.height / 2 }

      lines.push({
        id: `plug-in:${cardId}:${slot}`,
        source: rest[0].from,
        target: cardId,
        d: stub(attach, port),
        arrow: true,
        plug: { at, owner: cardId, port, side: 'in', card: rest[0].from, links: rest.map((link) => link.id), more: rest.length - 1 },
      })
    }
  }

  return { lines, fallbacks: whole.fallbacks, stubbed }
}

const stub = (from: Point, to: Point) => {
  const bend = (to.x - from.x) / 2

  return `M${from.x},${from.y} C${from.x + bend},${from.y} ${to.x - bend},${to.y} ${to.x},${to.y}`
}
