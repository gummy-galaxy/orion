import ELK from 'elkjs/lib/elk.bundled.js'
import { deriveWork, gated } from './derive'
import { GROUP_HEADER_HEIGHT, GROUP_PADDING, byId, isCluster, normalize, sizeOf, type AppNode, type Link } from './model'

const elk = new ELK()

/** The default flow keeps chains, and runs of interchangeable siblings, to about this many across. */
export const WRAP = 6
/** A wrapped row stops growing at about this width, so chains of large nested groups stack instead of sprawling. */
export const ROW_WIDTH = 2400

type Gap = { node: number; layer: number; component: number }
type Point = { x: number; y: number }
type Size = { width: number; height: number }
type Box = Point & Size
type Edge = [string, string]

/** Space between neighbors inside groups and at the top level. */
export const GAP = { inner: { x: 56, y: 24 }, top: { x: 120, y: 72 } }

/** The gap a column needs in front of it to fit the blocker Orion stands before one of its cards. */
export const BLOCKER_ROOM = 120

const INNER_GAP: Gap = { node: GAP.inner.y, layer: GAP.inner.x, component: 32 }
const TOP_GAP: Gap = { node: GAP.top.y, layer: GAP.top.x, component: 96 }

const elkOptions = (gap: Gap) => ({
  'elk.algorithm': 'layered',
  'elk.direction': 'RIGHT',
  'elk.spacing.nodeNode': String(gap.node),
  'elk.layered.spacing.nodeNodeBetweenLayers': String(gap.layer),
  'elk.spacing.componentComponent': String(gap.component),
})

/** Top to bottom, then left to right. */
const reading = (a: AppNode, b: AppNode) => a.position.y - b.position.y || a.position.x - b.position.x

/** Places sizes row by row, `columns` across. Each column is as wide as its widest box and each row as tall as its tallest. */
export function grid(sizes: Size[], columns: number, gap: number): { at: Point[] } & Size {
  const columnCount = Math.max(1, Math.min(Math.floor(columns), sizes.length))
  const widths = Array<number>(columnCount).fill(0)
  const heights: number[] = []

  sizes.forEach((size, i) => {
    const row = Math.floor(i / columnCount)

    widths[i % columnCount] = Math.max(widths[i % columnCount], size.width)
    heights[row] = Math.max(heights[row] ?? 0, size.height)
  })
  const offsets = (spans: number[]) => spans.map((_, i) => spans.slice(0, i).reduce((sum, span) => sum + span + gap, 0))
  const columnOffsets = offsets(widths)
  const rowOffsets = offsets(heights)

  return {
    at: sizes.map((_, i) => ({ x: columnOffsets[i % columnCount], y: rowOffsets[Math.floor(i / columnCount)] })),
    width: columnOffsets[columnCount - 1] + widths[columnCount - 1],
    height: (rowOffsets[rowOffsets.length - 1] ?? 0) + (heights[heights.length - 1] ?? 0),
  }
}

/** Columns of a left-to-right layout: boxes whose spans overlap sideways share one. */
function layersOf(boxes: Map<string, Box>) {
  const layers: { x: number; right: number; ids: string[] }[] = []

  for (const [id, box] of [...boxes].sort(([, a], [, b]) => a.x - b.x)) {
    const last = layers[layers.length - 1]

    if (last && box.x < last.right) {
      last.ids.push(id)
      last.right = Math.max(last.right, box.x + box.width)
    } else layers.push({ x: box.x, right: box.x + box.width, ids: [id] })
  }

  return layers
}

/** Widens the gap before each column holding a box in `guarded` to at least `room`, so the blocker in front of it fits. */
export function makeRoom(boxes: Map<string, Box>, guarded: Set<string>, room: number): Map<string, Box> {
  if (!guarded.size) return boxes

  const result = new Map<string, Box>()
  let shift = 0
  let right = -Infinity

  for (const layer of layersOf(boxes)) {
    if (layer.ids.some((id) => guarded.has(id))) shift += Math.max(0, room - (layer.x - right))

    for (const id of layer.ids) result.set(id, { ...boxes.get(id)!, x: boxes.get(id)!.x + shift })

    right = layer.right
  }

  return result
}

/**
 * Cuts a left-to-right layout into strips of at most `WRAP` layers, each no wider than `ROW_WIDTH` unless a single
 * layer is wider on its own, and stacks them top to bottom, so a long chain reads like lines of text. Returns null
 * when the layout already fits.
 */
export function wrapLayers(boxes: Map<string, Box>, gap: number): Map<string, Box> | null {
  const layers = layersOf(boxes)
  const strips: (typeof layers)[] = []

  for (const layer of layers) {
    const strip = strips[strips.length - 1]

    if (strip && strip.length < WRAP && layer.right - strip[0].x <= ROW_WIDTH) strip.push(layer)
    else strips.push([layer])
  }

  if (strips.length <= 1) return null

  const wrapped = new Map<string, Box>()
  let top = 0

  for (const strip of strips) {
    const inStrip = strip.flatMap((layer) => layer.ids.map((id) => boxes.get(id)!))
    const stripTop = Math.min(...inStrip.map((box) => box.y))
    const stripBottom = Math.max(...inStrip.map((box) => box.y + box.height))
    const shiftX = strip[0].x - layers[0].x

    for (const layer of strip)
      for (const id of layer.ids) {
        const box = boxes.get(id)!

        wrapped.set(id, { ...box, x: box.x - shiftX, y: box.y - stripTop + top })
      }

    top += stripBottom - stripTop + gap
  }

  return wrapped
}

const bounds = (boxes: Box[]): Box => {
  const x = Math.min(...boxes.map((box) => box.x))
  const y = Math.min(...boxes.map((box) => box.y))

  return {
    x,
    y,
    width: Math.max(...boxes.map((box) => box.x + box.width)) - x,
    height: Math.max(...boxes.map((box) => box.y + box.height)) - y,
  }
}

async function elkBoxes(units: ({ id: string } & Size)[], edges: Edge[], gap: Gap): Promise<Map<string, Box>> {
  const result = await elk.layout({
    id: 'root',
    layoutOptions: elkOptions(gap),
    children: units.map((unit) => ({ id: unit.id, width: unit.width, height: unit.height })),
    edges: edges.map(([source, target]) => ({ id: source + '>' + target, sources: [source], targets: [target] })),
  })

  return new Map(
    (result.children ?? []).map((child) => [child.id, { x: child.x ?? 0, y: child.y ?? 0, width: child.width ?? 0, height: child.height ?? 0 }]),
  )
}

/**
 * The default flow: ELK's layered layout, with two limits on width. Siblings that wait on and lead to exactly the
 * same things are interchangeable, so a run of more than `WRAP` of them is laid out as one grid. Chains longer than
 * `WRAP` steps wrap onto further rows, and the pieces are packed again.
 */
async function flow(children: AppNode[], edges: Edge[], gap: Gap, guarded: Set<string>): Promise<Map<string, Point>> {
  const ends = new Map(children.map((child) => [child.id, { in: [] as string[], out: [] as string[] }]))

  for (const [source, target] of edges) {
    ends.get(source)!.out.push(target)
    ends.get(target)!.in.push(source)
  }

  const runs = new Map<string, AppNode[]>()
  const runOf = new Map<string, AppNode[]>()

  for (const child of [...children].sort(reading)) {
    const childEnds = ends.get(child.id)!
    const key = childEnds.in.sort().join(',') + '|' + childEnds.out.sort().join(',')
    const run = runs.get(key) ?? []

    run.push(child)
    runs.set(key, run)
    runOf.set(child.id, run)
  }

  const unitOf = new Map<string, string>()
  const blocks = new Map<string, { members: AppNode[]; at: Point[] }>()
  const units: ({ id: string } & Size)[] = []

  for (const child of children) {
    if (unitOf.has(child.id)) continue

    const run = runOf.get(child.id)!

    if (run.length <= WRAP) {
      unitOf.set(child.id, child.id)
      units.push({ id: child.id, ...sizeOf(child) })
      continue
    }

    const id = '\0run:' + child.id
    const runGrid = grid(run.map(sizeOf), Math.min(WRAP, Math.ceil(Math.sqrt(run.length))), gap.node)

    for (const member of run) unitOf.set(member.id, id)

    blocks.set(id, { members: run, at: runGrid.at })
    units.push({ id, width: runGrid.width, height: runGrid.height })
  }

  const seen = new Set<string>()
  const unitEdges: Edge[] = []

  for (const [source, target] of edges) {
    const edge: Edge = [unitOf.get(source)!, unitOf.get(target)!]

    if (edge[0] === edge[1] || seen.has(edge.join('>'))) continue

    seen.add(edge.join('>'))
    unitEdges.push(edge)
  }

  let placed = await elkBoxes(units, unitEdges, gap)
  const root = new Map(units.map((unit) => [unit.id, unit.id]))
  const findRoot = (id: string): string => (root.get(id) === id ? id : findRoot(root.get(id)!))

  for (const [source, target] of unitEdges) root.set(findRoot(source), findRoot(target))

  const parts = new Map<string, Map<string, Box>>()

  for (const unit of units) {
    const part = parts.get(findRoot(unit.id)) ?? new Map<string, Box>()

    part.set(unit.id, placed.get(unit.id)!)
    parts.set(findRoot(unit.id), part)
  }

  const guardedUnits = new Set([...guarded].map((id) => unitOf.get(id)!))
  const wrapped = new Map([...parts].map(([id, part]) => [id, wrapLayers(part, gap.layer)]))
  // Columns only line up within a connected piece, and wrapped rows share them, so widening one keeps them lined up.
  const roomy = new Map(
    [...parts].map(([id, part]) => [
      id,
      [...part.keys()].some((unit) => guardedUnits.has(unit)) ? makeRoom(wrapped.get(id) ?? part, guardedUnits, BLOCKER_ROOM) : null,
    ]),
  )

  if ([...wrapped.values(), ...roomy.values()].some((boxes) => boxes)) {
    const shapes = [...parts].map(([id, part]) => {
      const boxes = roomy.get(id) ?? wrapped.get(id) ?? part

      return { id, boxes, frame: bounds([...boxes.values()]) }
    })
    const packed = await elkBoxes(
      shapes.map((shape) => ({ id: shape.id, width: shape.frame.width, height: shape.frame.height })),
      [],
      gap,
    )

    placed = new Map()

    for (const shape of shapes) {
      const at = packed.get(shape.id)!

      for (const [id, box] of shape.boxes) placed.set(id, { ...box, x: box.x - shape.frame.x + at.x, y: box.y - shape.frame.y + at.y })
    }
  }

  const positions = new Map<string, Point>()

  for (const child of children) {
    const unit = placed.get(unitOf.get(child.id)!)!
    const block = blocks.get(unitOf.get(child.id)!)
    const offset = block ? block.at[block.members.indexOf(child)] : { x: 0, y: 0 }

    positions.set(child.id, { x: unit.x + offset.x, y: unit.y + offset.y })
  }

  return positions
}

/**
 * Lays out the direct children of one group (or the top level when `groupId` is undefined) the way the group asks
 * to be arranged. Links between deeper descendants are lifted to the child that contains them, so nested groups are
 * placed as single boxes.
 */
export async function reflow(nodes: AppNode[], links: Link[], groupId: string | undefined): Promise<AppNode[]> {
  const nodeMap = byId(nodes)
  const group = groupId ? nodeMap.get(groupId) : undefined
  const arrange = group && isCluster(group) ? (group.data.arrange ?? 'auto') : 'auto'

  if (arrange === 'custom') return nodes

  const children = nodes.filter((node) => node.parentId === groupId)

  if (!children.length) return nodes

  const lift = (id: string): string | null => {
    let current: string | undefined = id

    while (current) {
      const node = nodeMap.get(current)

      if (!node) return null

      if (node.parentId === groupId) return current

      current = node.parentId
    }

    return null
  }

  const seen = new Set<string>()
  const edges: Edge[] = []
  const { status } = deriveWork(nodes, links)
  const guarded = new Set<string>()

  for (const link of links) {
    if (link.kind !== 'blocks') continue

    const source = lift(link.from)
    const target = lift(link.to)

    if (source && target === link.to && source !== target && gated(status, link.from, link.to)) guarded.add(target)

    if (!source || !target || source === target || seen.has(source + '>' + target)) continue

    seen.add(source + '>' + target)
    edges.push([source, target])
  }

  const positions = await flow(children, edges, groupId ? INNER_GAP : TOP_GAP, guarded)
  const offset = groupId ? { x: GROUP_PADDING, y: GROUP_HEADER_HEIGHT } : { x: 0, y: 0 }

  return normalize(
    nodes.map((node) => {
      const position = positions.get(node.id)

      return position ? { ...node, position: { x: position.x + offset.x, y: position.y + offset.y } } : node
    }),
  )
}
