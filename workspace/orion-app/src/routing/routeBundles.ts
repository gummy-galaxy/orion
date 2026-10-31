import { curvePath } from './curvePath'
import { sourcePort, targetPort } from './ports'
import type { Box, Point, RoutedLine, Routing, Scene } from './types'

/** How far outside a group its bundles gather. */
const JUNCTION_OFFSET = 36
/** Bundles of fewer links than this draw as separate curves. */
const MIN_BUNDLE = 2

/** The point just outside `group` on the side that faces `toward`, and the outward direction of that side. */
function junctionOf(group: Box, toward: Box): { point: Point; normal: Point } {
  const center = { x: group.x + group.width / 2, y: group.y + group.height / 2 }
  const other = { x: toward.x + toward.width / 2, y: toward.y + toward.height / 2 }
  const dx = (other.x - center.x) / group.width
  const dy = (other.y - center.y) / group.height
  const clamp = (value: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, value))

  if (Math.abs(dx) >= Math.abs(dy)) {
    const side = dx >= 0 ? 1 : -1
    const y = clamp(other.y, group.y + group.height * 0.25, group.y + group.height * 0.75)

    return { point: { x: side > 0 ? group.x + group.width + JUNCTION_OFFSET : group.x - JUNCTION_OFFSET, y }, normal: { x: side, y: 0 } }
  }

  const side = dy >= 0 ? 1 : -1
  const x = clamp(other.x, group.x + group.width * 0.25, group.x + group.width * 0.75)

  return { point: { x, y: side > 0 ? group.y + group.height + JUNCTION_OFFSET : group.y - JUNCTION_OFFSET }, normal: { x: 0, y: side } }
}

const cubic = (from: Point, out: Point, into: Point, to: Point) => `M${from.x},${from.y} C${out.x},${out.y} ${into.x},${into.y} ${to.x},${to.y}`

/**
 * Links between the same two groups share one trunk between the groups, and split into branches near each end. Links
 * inside a group, and lone links between groups, stay as today's curves.
 */
export function routeBundles(scene: Scene): Routing {
  const cards = new Map(scene.cards.map((card) => [card.id, card]))
  const groups = new Map(scene.groups.map((group) => [group.id, group]))
  const bundles = new Map<string, Scene['links']>()
  const lines: RoutedLine[] = []

  for (const link of scene.links) {
    const from = cards.get(link.from)!.group
    const to = cards.get(link.to)!.group

    if (from && to && from !== to) {
      const key = `${from}>${to}`

      bundles.set(key, [...(bundles.get(key) ?? []), link])
    } else {
      lines.push({
        id: link.id,
        source: link.from,
        target: link.to,
        d: curvePath(sourcePort(cards.get(link.from)!), targetPort(cards.get(link.to)!)),
        arrow: true,
      })
    }
  }

  for (const [key, links] of bundles) {
    if (links.length < MIN_BUNDLE) {
      for (const link of links) {
        lines.push({
          id: link.id,
          source: link.from,
          target: link.to,
          d: curvePath(sourcePort(cards.get(link.from)!), targetPort(cards.get(link.to)!)),
          arrow: true,
        })
      }

      continue
    }

    const [fromGroup, toGroup] = key.split('>').map((id) => groups.get(id)!)
    const out = junctionOf(fromGroup, toGroup)
    const into = junctionOf(toGroup, fromGroup)
    const span = Math.hypot(into.point.x - out.point.x, into.point.y - out.point.y) / 3
    const anchor = links[0]

    const outHandle = { x: out.point.x + out.normal.x * span, y: out.point.y + out.normal.y * span }
    const intoHandle = { x: into.point.x + into.normal.x * span, y: into.point.y + into.normal.y * span }

    lines.push({
      id: `trunk:${key}`,
      source: anchor.from,
      target: anchor.to,
      d: cubic(out.point, outHandle, intoHandle, into.point),
      arrow: false,
      width: Math.min(9, 2.5 + links.length * 1.2),
      label: `${links.length}`,
      // The middle of a cubic Bézier curve.
      labelAt: {
        x: (out.point.x + 3 * outHandle.x + 3 * intoHandle.x + into.point.x) / 8,
        y: (out.point.y + 3 * outHandle.y + 3 * intoHandle.y + into.point.y) / 8,
      },
    })

    // A card with several links in the bundle still draws one branch to the trunk.
    for (const from of new Set(links.map((link) => link.from))) {
      const port = sourcePort(cards.get(from)!)

      lines.push({
        id: `out:${key}:${from}`,
        source: from,
        target: anchor.to,
        d: cubic(port, { x: port.x + 48, y: port.y }, { x: out.point.x - out.normal.x * 40, y: out.point.y - out.normal.y * 40 }, out.point),
        arrow: false,
      })
    }

    for (const to of new Set(links.map((link) => link.to))) {
      const port = targetPort(cards.get(to)!)

      lines.push({
        id: `in:${key}:${to}`,
        source: anchor.from,
        target: to,
        d: cubic(into.point, { x: into.point.x - into.normal.x * 40, y: into.point.y - into.normal.y * 40 }, { x: port.x - 48, y: port.y }, port),
        arrow: true,
      })
    }
  }

  return { lines, fallbacks: 0 }
}
