import { absPos, byId, normalize, sizeOf, type AppNode, type Link } from './model'

/** Clear space Weave keeps between a line and any box it passes, and between boxes it moves. */
export const WEAVE_GAP = 16

/** `tangled` gave up on a level too knotted for nudges; `stuck` found no move that helps. Neither moves anything. */
export type WeaveOutcome = 'clean' | 'woven' | 'stuck' | 'tangled'
export type WeaveResult = {
  nodes: AppNode[]
  outcome: WeaveOutcome
  /** Lines running through or within the gap of a box they don't connect, before and after. */
  before: number
  after: number
  moved: number
}
export type WeaveOptions = { gap?: number; budgetMs?: number }

type Pt = { x: number; y: number }
type Box = Pt & { w: number; h: number }
type Line = { pts: Pt[]; box: Box }
/** One drawn link between two boxes at this level. `out` and `in` are its ends, relative to their box. */
type Wire = { a: number; b: number; from: string; to: string; out: Pt; in: Pt; weight: number }
type Move = Map<number, Pt>

/** Matches React Flow's default bezier edge between a right-hand source handle and a left-hand target. */
const HANDLE = 4.5
const CURVATURE = 0.25
const SAMPLES = 16

const LINE_COST = 10
const RELATED_WEIGHT = 0.6
const CROSS_COST = 1.5
const CRAMP_COST = 25
/** Moving a box this far from where it started costs 1; cost grows with the square of the distance. */
const DRIFT = 120
const IMPROVES = 0.01

const UP = { x: 0, y: -1 }
const DOWN = { x: 0, y: 1 }
const DIAGONAL = Math.SQRT1_2
const DIRECTIONS: Pt[] = [
  UP,
  DOWN,
  { x: -1, y: 0 },
  { x: 1, y: 0 },
  { x: -DIAGONAL, y: -DIAGONAL },
  { x: DIAGONAL, y: -DIAGONAL },
  { x: -DIAGONAL, y: DIAGONAL },
  { x: DIAGONAL, y: DIAGONAL },
]
const REACH_MIN = 240
const REACH_STEPS = 60
const SHOVE_LIMIT = 10
const BOXES_PER_ROUND = 8

/** More conflicts than this per box is a mess nudging can't fix; it needs a full layout. */
const NIGHTMARE_PER_BOX = 1.5
const NIGHTMARE_MIN = 24
/** By halfway through the budget, Weave gives up unless it has cleared this share of the conflicts. */
const HALFWAY_PROGRESS = 0.25

const control = (d: number) => (d >= 0 ? 0.5 * d : CURVATURE * 25 * Math.sqrt(-d))

function curve(s: Pt, t: Pt): Line {
  const c = control(t.x - s.x)
  const c1 = { x: s.x + c, y: s.y }
  const c2 = { x: t.x - c, y: t.y }
  const pts: Pt[] = []
  let x0 = Infinity
  let y0 = Infinity
  let x1 = -Infinity
  let y1 = -Infinity
  for (let i = 0; i <= SAMPLES; i++) {
    const u = i / SAMPLES
    const v = 1 - u
    const p = {
      x: v * v * v * s.x + 3 * v * v * u * c1.x + 3 * v * u * u * c2.x + u * u * u * t.x,
      y: v * v * v * s.y + 3 * v * v * u * c1.y + 3 * v * u * u * c2.y + u * u * u * t.y,
    }
    pts.push(p)
    x0 = Math.min(x0, p.x)
    y0 = Math.min(y0, p.y)
    x1 = Math.max(x1, p.x)
    y1 = Math.max(y1, p.y)
  }
  return { pts, box: { x: x0, y: y0, w: x1 - x0, h: y1 - y0 } }
}

const touches = (a: Box, b: Box, gap = 0) => a.x < b.x + b.w + gap && b.x < a.x + a.w + gap && a.y < b.y + b.h + gap && b.y < a.y + a.h + gap

/** Liang–Barsky clipping: whether the segment from `p` to `q` enters `r`. */
function segmentHits(p: Pt, q: Pt, r: Box): boolean {
  const dx = q.x - p.x
  const dy = q.y - p.y
  let t0 = 0
  let t1 = 1
  for (const [k, d] of [
    [-dx, p.x - r.x],
    [dx, r.x + r.w - p.x],
    [-dy, p.y - r.y],
    [dy, r.y + r.h - p.y],
  ]) {
    if (k === 0) {
      if (d < 0) return false
      continue
    }
    const t = d / k
    if (k < 0) {
      if (t > t1) return false
      t0 = Math.max(t0, t)
    } else {
      if (t < t0) return false
      t1 = Math.min(t1, t)
    }
  }
  return true
}

function lineHits(line: Line, r: Box): boolean {
  if (!touches(line.box, r)) return false
  for (let i = 1; i < line.pts.length; i++) if (segmentHits(line.pts[i - 1], line.pts[i], r)) return true
  return false
}

const orient = (a: Pt, b: Pt, c: Pt) => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)

function crossings(a: Line, b: Line): number {
  if (!touches(a.box, b.box)) return 0
  let n = 0
  for (let i = 1; i < a.pts.length; i++) {
    const p = a.pts[i - 1]
    const q = a.pts[i]
    for (let j = 1; j < b.pts.length; j++) {
      const r = b.pts[j - 1]
      const s = b.pts[j]
      if (orient(r, s, p) * orient(r, s, q) < 0 && orient(p, q, r) * orient(p, q, s) < 0) n++
    }
  }
  return n
}

/**
 * Untangles the direct children of one group (or the top level) by moving boxes off the lines that run through
 * them, as little as it can. It keeps the current arrangement rather than laying everything out again.
 *
 * This is a greedy, minimal-displacement local search in the spirit of PrEd's node–edge repulsion and VPSC's
 * least-squares overlap removal. Each round it tries, for the boxes with the most lines through them:
 * - sliding the box the shortest way off its lines, in one of eight directions;
 * - the same slide, shoving any boxes in the way along with it;
 * - sliding the box to the nearest spot clear of every line and box;
 * - dragging one end of a line so the line leaves the box;
 * - moving the box level with the things it links to, at the nearest clear spot.
 * It keeps the move that lowers the total cost most. The cost counts lines through boxes, line crossings, boxes
 * closer than the gap, and the square of how far each box has moved. It stops when no move helps, and moves
 * nothing when the level starts out, or stays, too tangled for nudges.
 */
export function weave(nodes: AppNode[], links: Link[], groupId: string | undefined, options: WeaveOptions = {}): WeaveResult {
  const gap = options.gap ?? WEAVE_GAP
  const budget = options.budgetMs ?? 400
  const map = byId(nodes)
  const kids = nodes.filter((n) => n.parentId === groupId).sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0))
  const index = new Map(kids.map((k, i) => [k.id, i]))
  const size = kids.map(sizeOf)
  const origin = kids.map((k) => ({ ...k.position }))
  const pos = origin.map((p) => ({ ...p }))
  const unchanged = (outcome: WeaveOutcome, before: number): WeaveResult => ({ nodes, outcome, before, after: before, moved: 0 })

  const owner = (id: string) => {
    let cur: string | undefined = id
    while (cur) {
      const i = index.get(cur)
      if (i !== undefined) return i
      cur = map.get(cur)?.parentId
    }
    return undefined
  }
  const wires: Wire[] = []
  const seen = new Set<string>()
  for (const l of links) {
    const a = owner(l.from)
    const b = owner(l.to)
    const from = map.get(l.from)
    const to = map.get(l.to)
    const key = l.from + '>' + l.to
    if (a === undefined || b === undefined || a === b || !from || !to || seen.has(key)) continue
    seen.add(key)
    const fa = absPos(from, map)
    const ta = absPos(to, map)
    const ka = absPos(kids[a], map)
    const kb = absPos(kids[b], map)
    const fs = sizeOf(from)
    const ts = sizeOf(to)
    wires.push({
      a,
      b,
      from: l.from,
      to: l.to,
      out: { x: fa.x - ka.x + fs.w + HANDLE, y: fa.y - ka.y + fs.h / 2 },
      in: { x: ta.x - kb.x - HANDLE, y: ta.y - kb.y + ts.h / 2 },
      weight: l.kind === 'related' ? RELATED_WEIGHT : 1,
    })
  }
  if (!wires.length) return unchanged('clean', 0)
  const incident = kids.map(() => [] as number[])
  wires.forEach((w, i) => {
    incident[w.a].push(i)
    incident[w.b].push(i)
  })

  type Place = (i: number) => Pt
  const here: Place = (i) => pos[i]
  const box = (i: number, p: Pt): Box => ({ x: p.x, y: p.y, w: size[i].w, h: size[i].h })
  const padded = (i: number, p: Pt): Box => ({ x: p.x - gap, y: p.y - gap, w: size[i].w + gap * 2, h: size[i].h + gap * 2 })
  const draw = (w: Wire, at: Place) => {
    const a = at(w.a)
    const b = at(w.b)
    return curve({ x: a.x + w.out.x, y: a.y + w.out.y }, { x: b.x + w.in.x, y: b.y + w.in.y })
  }
  const lines = wires.map((w) => draw(w, here))
  const shares = (v: Wire, w: Wire) => v.from === w.from || v.from === w.to || v.to === w.from || v.to === w.to
  const blocks = (i: number, p: Pt, w: number, line = lines[w]) => wires[w].a !== i && wires[w].b !== i && lineHits(line, padded(i, p))

  const conflicts = () => {
    const out: [number, number][] = []
    for (let w = 0; w < wires.length; w++) for (let i = 0; i < kids.length; i++) if (blocks(i, pos[i], w)) out.push([i, w])
    return out
  }

  /** The part of the total cost that a move can change: terms that involve a moved box or a line it drags along. */
  const score = (moved: Iterable<number>, dragged: Set<number>, at: Place, lineOf: (w: number) => Line) => {
    const m = new Set(moved)
    let c = 0
    for (const i of m) {
      const p = at(i)
      c += ((p.x - origin[i].x) ** 2 + (p.y - origin[i].y) ** 2) / DRIFT ** 2
      for (let j = 0; j < kids.length; j++) {
        if (j === i || (m.has(j) && j < i)) continue
        if (touches(box(i, p), box(j, at(j)), gap)) c += CRAMP_COST
      }
    }
    for (let w = 0; w < wires.length; w++) {
      const line = lineOf(w)
      const cost = LINE_COST * wires[w].weight
      if (dragged.has(w)) {
        for (let j = 0; j < kids.length; j++) if (blocks(j, at(j), w, line)) c += cost
        for (let v = 0; v < wires.length; v++) {
          if (v === w || (dragged.has(v) && v < w) || shares(wires[v], wires[w])) continue
          c += CROSS_COST * crossings(line, lineOf(v))
        }
      } else for (const j of m) if (blocks(j, at(j), w, line)) c += cost
    }
    return c
  }

  const delta = (move: Move) => {
    const dragged = new Set<number>()
    for (const i of move.keys()) for (const w of incident[i]) dragged.add(w)
    const at: Place = (i) => move.get(i) ?? pos[i]
    const redrawn = new Map([...dragged].map((w) => [w, draw(wires[w], at)]))
    return score(move.keys(), dragged, at, (w) => redrawn.get(w) ?? lines[w]) - score(move.keys(), dragged, here, (w) => lines[w])
  }

  const reach = (i: number, dir: Pt, ok: (p: Pt) => boolean): Pt | null => {
    const far = Math.max(REACH_MIN, 1.5 * Math.max(size[i].w, size[i].h))
    const step = far / REACH_STEPS
    for (let t = step; t <= far; t += step) {
      const p = { x: pos[i].x + dir.x * t, y: pos[i].y + dir.y * t }
      if (ok(p)) return p
    }
    return null
  }

  /** Clear of every box, and of every line except the box's own. */
  const free = (i: number, p: Pt) => {
    for (let j = 0; j < kids.length; j++) if (j !== i && touches(box(i, p), box(j, pos[j]), gap)) return false
    for (let w = 0; w < wires.length; w++) if (blocks(i, p, w)) return false
    return true
  }

  /** How far `b` has to travel along `dir` to sit `gap` away from `a`. */
  const clearance = (a: Box, b: Box, dir: Pt) => {
    let t = Infinity
    if (dir.x > 0) t = Math.min(t, (a.x + a.w + gap - b.x) / dir.x)
    if (dir.x < 0) t = Math.min(t, (b.x + b.w + gap - a.x) / -dir.x)
    if (dir.y > 0) t = Math.min(t, (a.y + a.h + gap - b.y) / dir.y)
    if (dir.y < 0) t = Math.min(t, (b.y + b.h + gap - a.y) / -dir.y)
    return Math.max(0, t)
  }

  /** Moves `i` to `p` and pushes whatever that crowds along `dir`, and so on, up to `SHOVE_LIMIT` boxes. */
  const shove = (i: number, p: Pt, dir: Pt): Move | null => {
    const move: Move = new Map([[i, p]])
    const queue = [i]
    while (queue.length) {
      const m = queue.shift()!
      const mb = box(m, move.get(m)!)
      for (let j = 0; j < kids.length; j++) {
        if (move.has(j) || !touches(mb, box(j, pos[j]), gap)) continue
        const t = clearance(mb, box(j, pos[j]), dir)
        move.set(j, { x: pos[j].x + dir.x * t, y: pos[j].y + dir.y * t })
        if (move.size > SHOVE_LIMIT) return null
        queue.push(j)
      }
    }
    return move.size > 1 ? move : null
  }

  /** Level with what the box links to, at the nearest clear height. */
  const settle = (i: number): Pt | null => {
    const ys = incident[i]
      .map((w) => {
        const wire = wires[w]
        return wire.a === i ? pos[wire.b].y + wire.in.y - wire.out.y : pos[wire.a].y + wire.out.y - wire.in.y
      })
      .sort((a, b) => a - b)
    if (!ys.length) return null
    const y = ys[Math.floor(ys.length / 2)]
    const step = Math.max(size[i].h, REACH_MIN) / REACH_STEPS
    for (let k = 0; k <= REACH_STEPS * 4; k++) {
      const p = { x: pos[i].x, y: y + (k % 2 ? -1 : 1) * Math.ceil(k / 2) * step }
      if (free(i, p)) return Math.abs(p.y - pos[i].y) > 1 ? p : null
    }
    return null
  }

  const candidates = (i: number, against: number[]): Move[] => {
    const out: Move[] = []
    for (const dir of DIRECTIONS) {
      const off = reach(i, dir, (p) => against.every((w) => !blocks(i, p, w)))
      if (off) {
        out.push(new Map([[i, off]]))
        const pushed = shove(i, off, dir)
        if (pushed) out.push(pushed)
      }
      const open = reach(i, dir, (p) => free(i, p))
      if (open) out.push(new Map([[i, open]]))
    }
    for (const w of against) {
      const wire = wires[w]
      for (const end of [wire.a, wire.b])
        for (const dir of [UP, DOWN]) {
          const p = reach(
            end,
            dir,
            (q) =>
              !blocks(
                i,
                pos[i],
                w,
                draw(wire, (k) => (k === end ? q : pos[k])),
              ),
          )
          if (p) out.push(new Map([[end, p]]))
        }
    }
    const level = settle(i)
    if (level) out.push(new Map([[i, level]]))
    return out
  }

  let found = conflicts()
  const before = found.length
  if (!before) return unchanged('clean', 0)
  if (before > Math.max(NIGHTMARE_MIN, kids.length * NIGHTMARE_PER_BOX)) return unchanged('tangled', before)

  const start = performance.now()
  let checked = false
  while (found.length) {
    const elapsed = performance.now() - start
    if (elapsed > budget) break
    if (!checked && elapsed > budget / 2) {
      checked = true
      if (before - found.length < before * HALFWAY_PROGRESS) return unchanged('tangled', before)
    }
    const against = new Map<number, number[]>()
    for (const [i, w] of found) against.set(i, [...(against.get(i) ?? []), w])
    const worst = [...against].sort((a, b) => b[1].length - a[1].length || a[0] - b[0]).slice(0, BOXES_PER_ROUND)
    let best: { move: Move; gain: number } | null = null
    for (const [i, ws] of worst)
      for (const move of candidates(i, ws)) {
        const gain = delta(move)
        if (gain < -IMPROVES && (!best || gain < best.gain)) best = { move, gain }
      }
    if (!best) break
    for (const [i, p] of best.move) pos[i] = { x: Math.round(p.x), y: Math.round(p.y) }
    for (const i of best.move.keys()) for (const w of incident[i]) lines[w] = draw(wires[w], here)
    found = conflicts()
  }

  const after = found.length
  if (after >= before) return unchanged('stuck', before)
  const moved = kids.filter((_, i) => pos[i].x !== origin[i].x || pos[i].y !== origin[i].y).length
  const placed = new Map(kids.map((k, i) => [k.id, pos[i]]))
  return {
    nodes: normalize(nodes.map((n) => (placed.has(n.id) ? { ...n, position: placed.get(n.id)! } : n))),
    outcome: 'woven',
    before,
    after,
    moved,
  }
}
