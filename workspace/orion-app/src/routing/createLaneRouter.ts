import { sourcePort, targetPort } from './ports'
import { roundedPath } from './roundedPath'
import type { Box, Point, Routing, Scene } from './types'

/** Clearance kept between a line and any card. */
const MARGIN = 10
/** How far a line runs straight out of a handle before it may turn. */
const STUB = 18
/** Space between parallel lines that share a channel. */
const LANE = 5
/** Runs closer than this read as one channel, so they get lanes instead of drawing on top of each other. */
const CHANNEL = 14
/** How far past a link's own box the router looks for a way around. */
const REACH = 240
/** Turn points tried on each side before giving up on a route. */
const TRIES = 6
const CELL = 256

type Rect = { left: number; top: number; right: number; bottom: number }

/** Cards bucketed by area, so a segment only tests the cards near it. */
function indexCards(cards: Box[]) {
  const rects: Rect[] = cards.map((card) => ({
    left: card.x - MARGIN,
    top: card.y - MARGIN,
    right: card.x + card.width + MARGIN,
    bottom: card.y + card.height + MARGIN,
  }))
  const buckets = new Map<number, number[]>()
  const keyOf = (column: number, row: number) => column * 100003 + row

  rects.forEach((rect, i) => {
    for (let column = Math.floor(rect.left / CELL); column <= Math.floor(rect.right / CELL); column++) {
      for (let row = Math.floor(rect.top / CELL); row <= Math.floor(rect.bottom / CELL); row++) {
        const key = keyOf(column, row)
        const bucket = buckets.get(key)

        if (bucket) bucket.push(i)
        else buckets.set(key, [i])
      }
    }
  })

  const seen = new Uint32Array(rects.length)
  let stamp = 0

  const near = (left: number, top: number, right: number, bottom: number, visit: (rect: Rect) => boolean) => {
    stamp++

    for (let column = Math.floor(left / CELL); column <= Math.floor(right / CELL); column++) {
      for (let row = Math.floor(top / CELL); row <= Math.floor(bottom / CELL); row++) {
        for (const i of buckets.get(keyOf(column, row)) ?? []) {
          if (seen[i] === stamp) continue

          seen[i] = stamp

          if (visit(rects[i]) === true) return true
        }
      }
    }

    return false
  }

  const clearH = (y: number, x1: number, x2: number) => {
    const lo = Math.min(x1, x2)
    const hi = Math.max(x1, x2)

    return !near(lo, y, hi, y, (rect) => rect.top < y && y < rect.bottom && rect.left < hi && rect.right > lo)
  }

  const clearV = (x: number, y1: number, y2: number) => {
    const lo = Math.min(y1, y2)
    const hi = Math.max(y1, y2)

    return !near(x, lo, x, hi, (rect) => rect.left < x && x < rect.right && rect.top < hi && rect.bottom > lo)
  }

  // Every card edge is a place a line can run past it, so these are the only columns and rows worth trying.
  const sortedUnique = (values: number[]) => [...new Set(values)].sort((a, b) => a - b)
  const columns = sortedUnique(rects.flatMap((rect) => [rect.left, rect.right]))
  const rows = sortedUnique(rects.flatMap((rect) => [rect.top, rect.bottom]))

  return { clearH, clearV, columns, rows }
}

/** The index of the first value at or above `value` in a sorted list. */
function lowerBound(values: number[], value: number): number {
  let lo = 0
  let hi = values.length

  while (lo < hi) {
    const middle = (lo + hi) >> 1

    if (values[middle] < value) lo = middle + 1
    else hi = middle
  }

  return lo
}

/** Values from a sorted list in order of their distance from `center`, with `extra` values merged in. */
function* outward(values: number[], center: number, extra: number[], lo = -Infinity, hi = Infinity) {
  const merged = extra.filter((value) => value >= lo && value <= hi).sort((a, b) => Math.abs(a - center) - Math.abs(b - center))
  let below = lowerBound(values, center) - 1
  let above = below + 1
  let next = 0

  while (true) {
    const down = below >= 0 && values[below] >= lo ? values[below] : undefined
    const up = above < values.length && values[above] <= hi ? values[above] : undefined
    const own = next < merged.length ? merged[next] : undefined
    const choices = [down, up, own].filter((value): value is number => value !== undefined)

    if (choices.length === 0) return

    const best = choices.reduce((a, b) => (Math.abs(b - center) < Math.abs(a - center) ? b : a))

    if (best === own) next++
    else if (best === down) below--
    else above++

    yield best
  }
}

type Cards = ReturnType<typeof indexCards>

/** Orthogonal points from one handle to the other that stay off every card, or null when no simple route fits. */
function findRoute(cards: Cards, from: Point, to: Point): Point[] | null {
  const start = from.x + STUB
  const end = to.x - STUB
  // Stubs leave from the card's own edge, so their clearance test starts just past its margin.
  const leave = from.x + MARGIN + 1
  const arrive = to.x - MARGIN - 1

  // Three runs, when the target is ahead and one vertical channel joins them.
  if (end >= start) {
    const middle = (start + end) / 2

    for (const x of outward(cards.columns, middle, [middle, start, end], start, end)) {
      if (cards.clearH(from.y, leave, x) && cards.clearV(x, from.y, to.y) && cards.clearH(to.y, x, arrive)) {
        return [from, { x, y: from.y }, { x, y: to.y }, to]
      }
    }
  }

  // Otherwise five: out to a column near the source, along a row channel, and down a column near the target.
  const firsts: number[] = []
  const lasts: number[] = []

  for (const x of outward(cards.columns, start, [start], start)) {
    if (!cards.clearH(from.y, leave, x) || firsts.length === TRIES) break

    firsts.push(x)
  }

  for (const x of outward(cards.columns, end, [end], -Infinity, end)) {
    if (!cards.clearH(to.y, x, arrive) || lasts.length === TRIES) break

    lasts.push(x)
  }

  const climb = (y: number) => Math.abs(y - from.y) + Math.abs(y - to.y)
  const top = Math.min(from.y, to.y)
  const bottom = Math.max(from.y, to.y)
  // No route can run less sideways than straight across, so a row whose climb alone uses up the best cost ends the
  // search: rows come in order of distance from the middle, and the climb only grows past the two ends.
  const across = Math.abs(to.x - from.x)
  let best: Point[] | null = null
  let bestCost = Infinity

  for (const y of outward(cards.rows, (top + bottom) / 2, [from.y, to.y], top - REACH, bottom + REACH)) {
    if (climb(y) + across >= bestCost) break

    const downs = firsts.filter((x) => cards.clearV(x, from.y, y))
    const ups = lasts.filter((x) => cards.clearV(x, y, to.y))

    for (const first of downs) {
      for (const last of ups) {
        const cost = climb(y) + (first - from.x) + Math.abs(last - first) + (to.x - last)

        if (cost < bestCost && cards.clearH(y, first, last)) {
          bestCost = cost
          best = [from, { x: first, y: from.y }, { x: first, y }, { x: last, y }, { x: last, y: to.y }, to]
        }
      }
    }
  }

  return best
}

/** A route that ignores cards, for links the search couldn't fit. */
function fallbackRoute(from: Point, to: Point): Point[] {
  const start = from.x + STUB
  const end = to.x - STUB

  if (end >= start) {
    const x = (start + end) / 2

    return [from, { x, y: from.y }, { x, y: to.y }, to]
  }

  const y = Math.max(from.y, to.y) + 60

  return [from, { x: start, y: from.y }, { x: start, y }, { x: end, y }, { x: end, y: to.y }, to]
}

type Run = { route: Point[]; index: number; at: number; lo: number; hi: number }

/**
 * Spreads runs that share a channel into side-by-side lanes. Runs that overlap get different lanes, and runs that
 * don't can share one, so a channel is only as wide as its busiest stretch.
 */
function assignLanes(runs: Run[], vertical: boolean) {
  runs.sort((a, b) => a.at - b.at)

  let first = 0

  for (let i = 1; i <= runs.length; i++) {
    if (i < runs.length && runs[i].at - runs[i - 1].at <= CHANNEL) continue

    const channel = runs.slice(first, i).sort((a, b) => a.lo - b.lo)
    const laneEnds: number[] = []
    const lanes = channel.map((run) => {
      let lane = laneEnds.findIndex((laneEnd) => laneEnd <= run.lo + 0.5)

      if (lane === -1) lane = laneEnds.length

      laneEnds[lane] = run.hi

      return lane
    })
    const center = channel.reduce((sum, run) => sum + run.at, 0) / channel.length

    channel.forEach((run, j) => {
      const at = laneEnds.length === 1 ? run.at : center + (lanes[j] - (laneEnds.length - 1) / 2) * LANE

      for (const point of [run.route[run.index], run.route[run.index + 1]]) {
        if (vertical) point.x = at
        else point.y = at
      }
    })

    first = i
  }
}

/** Whether any run of a route passes through a card's clearance. */
function crosses(route: Point[], card: Box): boolean {
  const left = card.x - MARGIN
  const top = card.y - MARGIN
  const right = card.x + card.width + MARGIN
  const bottom = card.y + card.height + MARGIN

  for (let i = 0; i < route.length - 1; i++) {
    const a = route[i]
    const b = route[i + 1]

    if (Math.max(a.x, b.x) >= left && Math.min(a.x, b.x) <= right && Math.max(a.y, b.y) >= top && Math.min(a.y, b.y) <= bottom) return true
  }

  return false
}

const sameBox = (a: Box, b: Box) => a.x === b.x && a.y === b.y && a.width === b.width && a.height === b.height

/**
 * Our own router: orthogonal lines that steer around cards, with shared runs spread into separate lanes. It remembers
 * each link's route, so when cards move it only reroutes the links on those cards or in their way, then spreads every
 * channel again.
 */
export function createLaneRouter() {
  let previous: { cards: Map<string, Box>; raw: Map<string, { from: string; to: string; route: Point[] | null }> } | null = null

  const route = (scene: Scene): Routing & { rerouted: number } => {
    const byId = new Map(scene.cards.map((card) => [card.id, card]))
    const cards = indexCards(scene.cards)
    const moved: Box[] = []

    if (previous) {
      for (const card of scene.cards) {
        const before = previous.cards.get(card.id)

        if (!before) moved.push(card)
        else if (!sameBox(before, card)) moved.push(before, card)
      }
    }

    const movedIds = new Set(moved.map((card) => card.id))
    const raw = new Map<string, { from: string; to: string; route: Point[] | null }>()
    let rerouted = 0

    for (const link of scene.links) {
      const known = previous?.raw.get(link.id)
      const stale =
        !known ||
        known.from !== link.from ||
        known.to !== link.to ||
        movedIds.has(link.from) ||
        movedIds.has(link.to) ||
        moved.some((card) => crosses(known.route ?? [], card))

      if (!stale) {
        raw.set(link.id, known)
        continue
      }

      rerouted++
      raw.set(link.id, { from: link.from, to: link.to, route: findRoute(cards, sourcePort(byId.get(link.from)!), targetPort(byId.get(link.to)!)) })
    }

    previous = { cards: new Map(scene.cards.map((card) => [card.id, card])), raw }

    let fallbacks = 0
    const routes = scene.links.map((link) => {
      const { route } = raw.get(link.id)!

      if (route) return route.map((point) => ({ ...point }))

      fallbacks++

      return fallbackRoute(sourcePort(byId.get(link.from)!), targetPort(byId.get(link.to)!))
    })
    const verticals: Run[] = []
    const horizontals: Run[] = []

    for (const route of routes) {
      // The first and last runs hold the handles, so only the ones between them move.
      for (let index = 1; index < route.length - 2; index++) {
        const a = route[index]
        const b = route[index + 1]

        if (a.x === b.x) verticals.push({ route, index, at: a.x, lo: Math.min(a.y, b.y), hi: Math.max(a.y, b.y) })
        else horizontals.push({ route, index, at: a.y, lo: Math.min(a.x, b.x), hi: Math.max(a.x, b.x) })
      }
    }

    assignLanes(verticals, true)
    assignLanes(horizontals, false)

    const lines = scene.links.map((link, i) => ({ id: link.id, source: link.from, target: link.to, d: roundedPath(routes[i]), arrow: true }))

    return { lines, fallbacks, rerouted }
  }

  return { route }
}
