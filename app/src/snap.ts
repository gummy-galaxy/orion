import { GAP } from './layout'
import { absPos, byId, sizeOf, type AppNode } from './model'

type Axis = 'x' | 'y'
type Box = { x: number; y: number; w: number; h: number }
/**
 * A `line` marks edges or centers lined up across nodes, and a `gap` marks matched
 * spacing. On the x axis a line runs vertically at `at` from `from` to `to`, and a gap
 * runs horizontally from `from` to `to` at height `at`.
 */
export type Guide = { kind: 'line' | 'gap'; axis: Axis; at: number; from: number; to: number }

/** Space wider than this between neighbors is open canvas, not spacing to match. */
const MAX_GAP = 240
/** How many grid cells out from the node it landed on a drop looks for room. */
const RINGS = 4

const lo = (b: Box, a: Axis) => (a === 'x' ? b.x : b.y)
const len = (b: Box, a: Axis) => (a === 'x' ? b.w : b.h)
const hi = (b: Box, a: Axis) => lo(b, a) + len(b, a)
const mid = (b: Box, a: Axis) => lo(b, a) + len(b, a) / 2
const cross = (a: Axis): Axis => (a === 'x' ? 'y' : 'x')
/** Whether two boxes cover some of the same span along `a`. */
const share = (p: Box, q: Box, a: Axis) => lo(p, a) < hi(q, a) && lo(q, a) < hi(p, a)
const intersects = (p: Box, q: Box) => share(p, q, 'x') && share(p, q, 'y')
const apart = (p: Box, q: Box, a: Axis) => Math.max(0, lo(q, a) - hi(p, a), lo(p, a) - hi(q, a))
const overlap = (p: Box, q: Box, a: Axis) => Math.max(0, Math.min(hi(p, a), hi(q, a)) - Math.max(lo(p, a), lo(q, a)))

type Hit = { d: number; guide: Guide }
type Scene = { moving: Box; others: Box[]; gaps: Record<Axis, number[]> }

/** Spacing neighbors already keep along `axis`, most common first. */
function spacing(boxes: Box[], axis: Axis): number[] {
  const counts = new Map<number, number>()
  for (const p of boxes) {
    let nearest = Infinity
    for (const q of boxes) {
      const g = lo(q, axis) - hi(p, axis)
      if (q !== p && share(p, q, cross(axis)) && g > 0 && g < nearest) nearest = g
    }
    if (nearest <= MAX_GAP) counts.set(Math.round(nearest), (counts.get(Math.round(nearest)) ?? 0) + 1)
  }
  return [...counts].sort((a, b) => b[1] - a[1]).map(([g]) => g)
}

/** The dragged nodes as one box, and their siblings, in canvas coordinates. */
function scene(nodes: AppNode[], ids: string[]): Scene | null {
  const map = byId(nodes)
  const moved = ids.map((id) => map.get(id)).filter((n) => !!n)
  if (!moved.length) return null
  const box = (n: AppNode): Box => ({ ...absPos(n, map), w: sizeOf(n).w, h: sizeOf(n).h })
  const boxes = moved.map(box)
  const x = Math.min(...boxes.map((b) => b.x))
  const y = Math.min(...boxes.map((b) => b.y))
  const moving = { x, y, w: Math.max(...boxes.map((b) => b.x + b.w)) - x, h: Math.max(...boxes.map((b) => b.y + b.h)) - y }
  const parent = moved[0].parentId
  const skip = new Set(ids)
  const others = nodes.filter((n) => n.parentId === parent && !skip.has(n.id)).map(box)
  const fallback = parent ? GAP.inner : GAP.top
  const gaps = (axis: Axis) => [...new Set([...spacing(others, axis).slice(0, 2), fallback[axis]])]
  return { moving, others, gaps: { x: gaps('x'), y: gaps('y') } }
}

/** Every edge, center, and spacing within `tolerance` of the moving box along `axis`. */
function hits({ moving: m, others, gaps }: Scene, axis: Axis, tolerance: number): Hit[] {
  const c = cross(axis)
  const out: Hit[] = []
  const add = (d: number, guide: Guide) => Math.abs(d) <= tolerance && out.push({ d, guide })
  for (const o of others) {
    const beside = share(m, o, c)
    const from = Math.min(lo(m, c), lo(o, c))
    const to = Math.max(hi(m, c), hi(o, c))
    const pairs = [
      [lo(m, axis), lo(o, axis)],
      [hi(m, axis), hi(o, axis)],
      [mid(m, axis), mid(o, axis)],
    ]
    // Side by side, meeting edges would mean touching; elsewhere they make a column.
    if (!beside) pairs.push([lo(m, axis), hi(o, axis)], [hi(m, axis), lo(o, axis)])
    for (const [edge, at] of pairs) add(at - edge, { kind: 'line', axis, at, from, to })
    if (!beside) continue
    const at = Math.max(lo(m, c), lo(o, c)) + overlap(m, o, c) / 2
    for (const g of gaps[axis]) {
      add(hi(o, axis) + g - lo(m, axis), { kind: 'gap', axis, at, from: hi(o, axis), to: hi(o, axis) + g })
      add(lo(o, axis) - g - hi(m, axis), { kind: 'gap', axis, at, from: lo(o, axis) - g, to: lo(o, axis) })
    }
  }
  return out
}

function shift(nodes: AppNode[], ids: string[], dx: number, dy: number): AppNode[] {
  const moved = new Set(ids)
  return nodes.map((n) => (moved.has(n.id) ? { ...n, position: { x: n.position.x + dx, y: n.position.y + dy } } : n))
}

/**
 * Pulls dragged nodes onto nearby edges, centers, and the spacing their siblings use.
 * Each pull only holds within `tolerance` (canvas units), so dragging on slides past it.
 */
export function snapDrag(nodes: AppNode[], ids: string[], tolerance: number): AppNode[] {
  const s = scene(nodes, ids)
  if (!s) return nodes
  const pull = (axis: Axis) =>
    hits(s, axis, tolerance).reduce<Hit | null>((best, h) => (!best || Math.abs(h.d) < Math.abs(best.d) ? h : best), null)?.d ?? 0
  const dx = pull('x')
  const dy = pull('y')
  return dx || dy ? shift(nodes, ids, dx, dy) : nodes
}

/** Guides for whatever the nodes being dragged now line up with. */
export function snapGuides(nodes: AppNode[]): Guide[] {
  const ids = nodes.filter((n) => n.dragging).map((n) => n.id)
  const s = ids.length ? scene(nodes, ids) : null
  if (!s) return []
  const lines = new Map<string, Guide>()
  for (const axis of ['x', 'y'] as const)
    for (const { guide: g } of hits(s, axis, 0.5)) {
      const key = g.kind === 'line' ? `${axis}:${Math.round(g.at)}` : `${axis}:${g.from}:${g.to}:${g.at}`
      const seen = lines.get(key)
      lines.set(key, seen ? { ...seen, from: Math.min(seen.from, g.from), to: Math.max(seen.to, g.to) } : g)
    }
  return [...lines.values()]
}

/**
 * Where a drop settles. Landing on a sibling, or throwing a node quickly beside one,
 * moves it to the nearest open cell of that sibling's grid. Returns null to stay put.
 */
export function settleDrop(nodes: AppNode[], ids: string[], thrown: boolean): AppNode[] | null {
  const s = scene(nodes, ids)
  if (!s) return null
  const { moving: m, others } = s
  const gap = { x: s.gaps.x[0], y: s.gaps.y[0] }
  const reach = Math.max(gap.x, gap.y) * 2
  const area = (o: Box) => overlap(m, o, 'x') * overlap(m, o, 'y')
  const distance = (o: Box) => Math.hypot(apart(m, o, 'x'), apart(m, o, 'y'))
  const landed = others.filter((o) => intersects(m, o)).sort((a, b) => area(b) - area(a))[0]
  const anchor = landed ?? (thrown ? others.filter((o) => distance(o) <= reach).sort((a, b) => distance(a) - distance(b))[0] : undefined)
  if (!anchor) return null

  // The anchor's columns and rows, lined up by either edge so different sizes still fit.
  const xs: number[] = []
  const ys: number[] = []
  for (let i = -RINGS; i <= RINGS; i++) {
    xs.push(anchor.x + i * (anchor.w + gap.x), anchor.x + anchor.w - m.w + i * (anchor.w + gap.x))
    ys.push(anchor.y + i * (anchor.h + gap.y), anchor.y + anchor.h - m.h + i * (anchor.h + gap.y))
  }
  const clear = Math.min(gap.x, gap.y) / 2
  let best: { x: number; y: number; d: number } | null = null
  for (const x of xs)
    for (const y of ys) {
      const room = { x: x - clear, y: y - clear, w: m.w + clear * 2, h: m.h + clear * 2 }
      if (others.some((o) => intersects(room, o))) continue
      const d = Math.hypot(x - m.x, y - m.y)
      if (!best || d < best.d) best = { x, y, d }
    }
  if (!best || best.d < 0.5 || (!landed && best.d > reach)) return null
  return shift(nodes, ids, best.x - m.x, best.y - m.y)
}
