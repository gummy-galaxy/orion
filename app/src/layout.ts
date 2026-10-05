import ELK from 'elkjs/lib/elk.bundled.js'
import type { ElkExtendedEdge } from 'elkjs/lib/elk-api'
import { HEAD, PAD, byId, isCluster, ancestors, normalize, sizeOf, type AppNode, type Link } from './model'

const elk = new ELK()

/** The default flow keeps chains, and runs of interchangeable siblings, to about this many across. */
export const WRAP = 6
/** A wrapped row stops growing at about this width, so chains of large nested groups stack instead of sprawling. */
export const ROW_WIDTH = 2400

type Gap = { node: number; layer: number; component: number }
type Point = { x: number; y: number }
type Size = { w: number; h: number }
type Box = Point & Size
type Edge = [string, string]

const INNER: Gap = { node: 24, layer: 56, component: 32 }
const TOP: Gap = { node: 72, layer: 120, component: 96 }

const elkOptions = (gap: Gap) => ({
  'elk.algorithm': 'layered',
  'elk.direction': 'RIGHT',
  'elk.edgeRouting': 'ORTHOGONAL',
  'elk.spacing.nodeNode': String(gap.node),
  'elk.layered.spacing.nodeNodeBetweenLayers': String(gap.layer),
  'elk.spacing.componentComponent': String(gap.component),
})

/** Top to bottom, then left to right. */
const reading = (a: AppNode, b: AppNode) => a.position.y - b.position.y || a.position.x - b.position.x

/** Places sizes row by row, `columns` across. Each column is as wide as its widest box and each row as tall as its tallest. */
export function grid(sizes: Size[], columns: number, gap: number): { at: Point[] } & Size {
  const cols = Math.max(1, Math.min(Math.floor(columns), sizes.length))
  const widths = Array<number>(cols).fill(0)
  const heights: number[] = []
  sizes.forEach((s, i) => {
    const row = Math.floor(i / cols)
    widths[i % cols] = Math.max(widths[i % cols], s.w)
    heights[row] = Math.max(heights[row] ?? 0, s.h)
  })
  const offsets = (spans: number[]) => spans.map((_, i) => spans.slice(0, i).reduce((sum, s) => sum + s + gap, 0))
  const xs = offsets(widths)
  const ys = offsets(heights)
  return {
    at: sizes.map((_, i) => ({ x: xs[i % cols], y: ys[Math.floor(i / cols)] })),
    w: xs[cols - 1] + widths[cols - 1],
    h: (ys[ys.length - 1] ?? 0) + (heights[heights.length - 1] ?? 0),
  }
}

/** Children in dependency order, taking whatever is free in reading order. A cycle falls back to reading order. */
export function dependencyOrder(kids: AppNode[], edges: Edge[]): AppNode[] {
  const waiting = new Map(kids.map((k) => [k.id, 0]))
  for (const [, to] of edges) waiting.set(to, (waiting.get(to) ?? 0) + 1)
  const left = [...kids].sort(reading)
  const out: AppNode[] = []
  while (left.length) {
    const [next] = left.splice(
      Math.max(
        0,
        left.findIndex((k) => waiting.get(k.id) === 0),
      ),
      1,
    )
    out.push(next)
    for (const [from, to] of edges) if (from === next.id) waiting.set(to, (waiting.get(to) ?? 0) - 1)
  }
  return out
}

/**
 * Cuts a left-to-right layout into strips of at most `WRAP` layers, each no wider than `ROW_WIDTH` unless a single
 * layer is wider on its own, and stacks them top to bottom, so a long chain reads like lines of text. Returns null
 * when the layout already fits.
 */
export function wrapLayers(boxes: Map<string, Box>, gap: number): Map<string, Box> | null {
  const layers: { x: number; right: number; ids: string[] }[] = []
  for (const [id, b] of [...boxes].sort(([, a], [, b]) => a.x - b.x)) {
    const last = layers[layers.length - 1]
    if (last && b.x < last.right) {
      last.ids.push(id)
      last.right = Math.max(last.right, b.x + b.w)
    } else layers.push({ x: b.x, right: b.x + b.w, ids: [id] })
  }
  const strips: (typeof layers)[] = []
  for (const l of layers) {
    const strip = strips[strips.length - 1]
    if (strip && strip.length < WRAP && l.right - strip[0].x <= ROW_WIDTH) strip.push(l)
    else strips.push([l])
  }
  if (strips.length <= 1) return null
  const out = new Map<string, Box>()
  let top = 0
  for (const strip of strips) {
    const inStrip = strip.flatMap((l) => l.ids.map((id) => boxes.get(id)!))
    const y0 = Math.min(...inStrip.map((b) => b.y))
    const y1 = Math.max(...inStrip.map((b) => b.y + b.h))
    const dx = strip[0].x - layers[0].x
    for (const l of strip)
      for (const id of l.ids) {
        const b = boxes.get(id)!
        out.set(id, { ...b, x: b.x - dx, y: b.y - y0 + top })
      }
    top += y1 - y0 + gap
  }
  return out
}

const bounds = (boxes: Box[]): Box => {
  const x = Math.min(...boxes.map((b) => b.x))
  const y = Math.min(...boxes.map((b) => b.y))
  return { x, y, w: Math.max(...boxes.map((b) => b.x + b.w)) - x, h: Math.max(...boxes.map((b) => b.y + b.h)) - y }
}

/** An arrow's path from its start through each bend to its end, in the coordinates of the group's children. */
export type Route = Point[]

async function elkBoxes(
  units: { id: string; w: number; h: number }[],
  edges: Edge[],
  gap: Gap,
): Promise<{ boxes: Map<string, Box>; routes: Map<string, Route> }> {
  const res = await elk.layout({
    id: 'root',
    layoutOptions: elkOptions(gap),
    children: units.map((u) => ({ id: u.id, width: u.w, height: u.h })),
    edges: edges.map(([a, b]) => ({ id: a + '>' + b, sources: [a], targets: [b] })),
  })
  const boxes = new Map((res.children ?? []).map((c) => [c.id, { x: c.x ?? 0, y: c.y ?? 0, w: c.width ?? 0, h: c.height ?? 0 }]))
  const routes = new Map<string, Route>()
  for (const e of (res.edges ?? []) as ElkExtendedEdge[]) {
    const s = e.sections?.[0]
    if (s)
      routes.set(
        e.id,
        [s.startPoint, ...(s.bendPoints ?? []), s.endPoint].map(({ x, y }) => ({ x, y })),
      )
  }
  return { boxes, routes }
}

/**
 * The default flow: ELK's layered layout, with two limits on width. Siblings that wait on and lead to exactly the
 * same things are interchangeable, so a run of more than `WRAP` of them is laid out as one grid. Chains longer than
 * `WRAP` steps wrap onto further rows, and the pieces are packed again.
 */
async function flow(kids: AppNode[], edges: Edge[], gap: Gap): Promise<{ pos: Map<string, Point>; routes: Map<string, Route> }> {
  const ends = new Map(kids.map((k) => [k.id, { in: [] as string[], out: [] as string[] }]))
  for (const [a, b] of edges) {
    ends.get(a)!.out.push(b)
    ends.get(b)!.in.push(a)
  }
  const runs = new Map<string, AppNode[]>()
  const runOf = new Map<string, AppNode[]>()
  for (const k of [...kids].sort(reading)) {
    const e = ends.get(k.id)!
    const key = e.in.sort().join(',') + '|' + e.out.sort().join(',')
    const run = runs.get(key) ?? []
    run.push(k)
    runs.set(key, run)
    runOf.set(k.id, run)
  }
  const unitOf = new Map<string, string>()
  const blocks = new Map<string, { members: AppNode[]; at: Point[] }>()
  const units: { id: string; w: number; h: number }[] = []
  for (const k of kids) {
    if (unitOf.has(k.id)) continue
    const run = runOf.get(k.id)!
    if (run.length <= WRAP) {
      unitOf.set(k.id, k.id)
      units.push({ id: k.id, ...sizeOf(k) })
      continue
    }
    const id = '\0run:' + k.id
    const g = grid(run.map(sizeOf), Math.min(WRAP, Math.ceil(Math.sqrt(run.length))), gap.node)
    for (const m of run) unitOf.set(m.id, id)
    blocks.set(id, { members: run, at: g.at })
    units.push({ id, w: g.w, h: g.h })
  }
  const seen = new Set<string>()
  const unitEdges: Edge[] = []
  for (const [a, b] of edges) {
    const e: Edge = [unitOf.get(a)!, unitOf.get(b)!]
    if (e[0] === e[1] || seen.has(e.join('>'))) continue
    seen.add(e.join('>'))
    unitEdges.push(e)
  }

  const first = await elkBoxes(units, unitEdges, gap)
  let placed = first.boxes
  const root = new Map(units.map((u) => [u.id, u.id]))
  const find = (id: string): string => (root.get(id) === id ? id : find(root.get(id)!))
  for (const [a, b] of unitEdges) root.set(find(a), find(b))
  const parts = new Map<string, Map<string, Box>>()
  for (const u of units) {
    const part = parts.get(find(u.id)) ?? new Map<string, Box>()
    part.set(u.id, placed.get(u.id)!)
    parts.set(find(u.id), part)
  }
  const wrapped = new Map([...parts].map(([id, part]) => [id, wrapLayers(part, gap.layer)]))
  if ([...wrapped.values()].some((w) => w)) {
    const shapes = [...parts].map(([id, part]) => {
      const boxes = wrapped.get(id) ?? part
      return { id, boxes, frame: bounds([...boxes.values()]) }
    })
    const { boxes: packed } = await elkBoxes(
      shapes.map((s) => ({ id: s.id, w: s.frame.w, h: s.frame.h })),
      [],
      gap,
    )
    placed = new Map()
    for (const s of shapes) {
      const at = packed.get(s.id)!
      for (const [id, b] of s.boxes) placed.set(id, { ...b, x: b.x - s.frame.x + at.x, y: b.y - s.frame.y + at.y })
    }
  }

  const pos = new Map<string, Point>()
  for (const k of kids) {
    const unit = placed.get(unitOf.get(k.id)!)!
    const block = blocks.get(unitOf.get(k.id)!)
    const offset = block ? block.at[block.members.indexOf(k)] : { x: 0, y: 0 }
    pos.set(k.id, { x: unit.x + offset.x, y: unit.y + offset.y })
  }
  // Wrapping and packing move whole strips, so a route survives only when both of its ends moved together.
  const routes = new Map<string, Route>()
  for (const [a, b] of edges) {
    const route = unitOf.get(a) === a && unitOf.get(b) === b ? first.routes.get(a + '>' + b) : undefined
    if (!route) continue
    const da = { x: placed.get(a)!.x - first.boxes.get(a)!.x, y: placed.get(a)!.y - first.boxes.get(a)!.y }
    const db = { x: placed.get(b)!.x - first.boxes.get(b)!.x, y: placed.get(b)!.y - first.boxes.get(b)!.y }
    if (da.x === db.x && da.y === db.y)
      routes.set(
        a + '>' + b,
        route.map((p) => ({ x: p.x + da.x, y: p.y + da.y })),
      )
  }
  return { pos, routes }
}

/**
 * Lays out the direct children of one group (or the top level when `groupId` is undefined) the way the group asks
 * to be arranged. Links between deeper descendants are lifted to the child that contains them, so nested groups are
 * placed as single boxes.
 */
export async function reflow(nodes: AppNode[], links: Link[], groupId: string | undefined): Promise<AppNode[]> {
  const { group, arrange, kids, edges } = children(nodes, links, groupId)
  if (arrange === 'custom' || !kids.length) return nodes
  const gap = groupId ? INNER : TOP
  let pos: Map<string, Point>
  if (arrange === 'grid') {
    const order = dependencyOrder(kids, edges)
    const columns = group && isCluster(group) ? group.data.columns : undefined
    const g = grid(order.map(sizeOf), columns ?? WRAP, gap.node)
    pos = new Map(order.map((k, i) => [k.id, g.at[i]]))
  } else pos = (await flow(kids, edges, gap)).pos
  const offset = groupId ? { x: PAD, y: HEAD } : { x: 0, y: 0 }
  return normalize(nodes.map((n) => (pos.has(n.id) ? { ...n, position: { x: pos.get(n.id)!.x + offset.x, y: pos.get(n.id)!.y + offset.y } } : n)))
}

/**
 * ELK's routes for the links between a group's direct children, keyed `from>to`, in the same coordinates as the
 * children's positions. Only an automatic group that still sits where its flow put it has them, since the routes
 * come from laying it out again.
 */
export async function routesFor(nodes: AppNode[], links: Link[], groupId: string | undefined): Promise<Map<string, Route>> {
  const { arrange, kids, edges } = children(nodes, links, groupId)
  if (arrange !== 'auto' || !kids.length || !edges.length) return new Map()
  const { pos, routes } = await flow(kids, edges, groupId ? INNER : TOP)
  const shift = { x: kids[0].position.x - pos.get(kids[0].id)!.x, y: kids[0].position.y - pos.get(kids[0].id)!.y }
  const moved = kids.some((k) => Math.abs(k.position.x - pos.get(k.id)!.x - shift.x) > 1 || Math.abs(k.position.y - pos.get(k.id)!.y - shift.y) > 1)
  if (moved) return new Map()
  return new Map([...routes].map(([key, route]) => [key, route.map((p) => ({ x: p.x + shift.x, y: p.y + shift.y }))]))
}

/** A group's direct children and the blocking links between them, with links between descendants lifted to them. */
function children(nodes: AppNode[], links: Link[], groupId: string | undefined) {
  const map = byId(nodes)
  const group = groupId ? map.get(groupId) : undefined
  const arrange = group && isCluster(group) ? (group.data.arrange ?? 'auto') : 'auto'
  const kids = nodes.filter((n) => n.parentId === groupId)
  const lift = (id: string): string | null => {
    let cur: string | undefined = id
    while (cur) {
      const n = map.get(cur)
      if (!n) return null
      if (n.parentId === groupId) return cur
      cur = n.parentId
    }
    return null
  }
  const seen = new Set<string>()
  const edges: Edge[] = []
  for (const l of links) {
    if (l.kind !== 'blocks') continue
    const a = lift(l.from)
    const b = lift(l.to)
    if (!a || !b || a === b || seen.has(a + '>' + b)) continue
    seen.add(a + '>' + b)
    edges.push([a, b])
  }
  return { group, arrange, kids, edges }
}

/** Lays out every group from the deepest up, then the top level. */
export async function reflowAll(nodes: AppNode[], links: Link[]): Promise<AppNode[]> {
  const map = byId(nodes)
  const groups = nodes.filter(isCluster).sort((a, b) => ancestors(b.id, map).length - ancestors(a.id, map).length)
  let next = normalize(nodes)
  for (const g of groups) next = await reflow(next, links, g.id)
  return reflow(next, links, undefined)
}
