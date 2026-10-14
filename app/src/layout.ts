import ELK from 'elkjs/lib/elk.bundled.js'
import {
  GROUP_HEADER_HEIGHT,
  GROUP_PADDING,
  TASK_HEIGHT,
  TASK_WIDTH,
  ancestors,
  byId,
  isCluster,
  normalize,
  sizeOf,
  type AppNode,
  type Link,
} from './model'
import type { CardSize } from './cardSize'

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
/** A linked block or a lone sibling, placed as one piece, with the outside group it's tied to. */
type Shape = { ids: string[]; first: AppNode; boxes: Map<string, Box>; size: Size; isLinked: boolean; cluster: string }

/** A cluster of work tied to one outside group needs at least this many cards to sit apart from the rest. */
const CLUSTER_MINIMUM = 3

/** Space between neighbors inside groups and at the top level. */
export const GAP = { inner: { x: 56, y: 24 }, top: { x: 120, y: 72 } }

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

/**
 * Cuts a left-to-right layout into strips of at most `WRAP` layers, each no wider than `ROW_WIDTH` unless a single
 * layer is wider on its own, and stacks them top to bottom, so a long chain reads like lines of text. Returns null
 * when the layout already fits.
 */
export function wrapLayers(boxes: Map<string, Box>, gap: number): Map<string, Box> | null {
  const layers: { x: number; right: number; ids: string[] }[] = []

  for (const [id, box] of [...boxes].sort(([, a], [, b]) => a.x - b.x)) {
    const last = layers[layers.length - 1]

    if (last && box.x < last.right) {
      last.ids.push(id)
      last.right = Math.max(last.right, box.x + box.width)
    } else layers.push({ x: box.x, right: box.x + box.width, ids: [id] })
  }

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

/** Finds the root of each id's linked component, so ids that link to each other share one root. */
function linkRoots(ids: string[], edges: Edge[]): Map<string, string> {
  const parent = new Map(ids.map((id) => [id, id]))

  const find = (id: string): string => {
    let current = id

    while (parent.get(current) !== current) {
      const grandparent = parent.get(parent.get(current)!)!

      parent.set(current, grandparent)
      current = grandparent
    }

    return current
  }

  for (const [source, target] of edges) parent.set(find(source), find(target))

  return new Map(ids.map((id) => [id, find(id)]))
}

/** Wraps a linked block that runs too wide, then moves its top left corner to the origin. */
function frameBlock(boxes: Map<string, Box>, gap: number): { boxes: Map<string, Box>; size: Size } {
  const wrapped = wrapLayers(boxes, gap) ?? boxes
  const frame = bounds([...wrapped.values()])

  return {
    boxes: new Map([...wrapped].map(([id, box]) => [id, { ...box, x: box.x - frame.x, y: box.y - frame.y }])),
    size: { width: frame.width, height: frame.height },
  }
}

/** The value that occurs most often, breaking ties by sort order so the same input always gives the same answer. */
function mostCommon(values: string[]): string {
  const counts = new Map<string, number>()

  for (const value of values) counts.set(value, (counts.get(value) ?? 0) + 1)

  return [...counts].sort(([a, first], [b, second]) => second - first || a.localeCompare(b))[0]?.[0] ?? ''
}

/**
 * The default flow. Siblings that link to each other form a block, laid out by ELK's layered algorithm with two
 * limits on width: a run of more than `WRAP` interchangeable siblings is laid out as a grid of its own, and chains
 * longer than `WRAP` steps wrap onto further rows.
 *
 * Pieces are then sorted into clusters by `outside`, the group outside this one that each sibling links to most, so
 * work tied to the same place sits together. Clusters stack top to bottom in reading order. In each, the linked blocks
 * pack into rows of their own, each reading left to right, and the siblings with no links follow in a grid.
 */
async function flow(
  children: AppNode[],
  edges: Edge[],
  gap: Gap,
  cardSize: CardSize,
  outside: Map<string, string> = new Map(),
): Promise<Map<string, Point>> {
  const ends = new Map(children.map((child) => [child.id, { in: [] as string[], out: [] as string[] }]))

  for (const [source, target] of edges) {
    ends.get(source)!.out.push(target)
    ends.get(target)!.in.push(source)
  }

  const runs = new Map<string, AppNode[]>()
  const runOf = new Map<string, AppNode[]>()

  for (const child of [...children].sort(reading)) {
    const childEnds = ends.get(child.id)!

    if (!childEnds.in.length && !childEnds.out.length) continue

    const key = childEnds.in.sort().join(',') + '|' + childEnds.out.sort().join(',')
    const run = runs.get(key) ?? []

    run.push(child)
    runs.set(key, run)
    runOf.set(child.id, run)
  }

  const unitOf = new Map<string, string>()
  const members = new Map<string, AppNode[]>()
  const sizes = new Map<string, Size>()
  const offsetOf = new Map<string, Point>()

  for (const child of children) {
    if (unitOf.has(child.id)) continue

    const run = runOf.get(child.id) ?? []

    if (run.length <= WRAP) {
      unitOf.set(child.id, child.id)
      members.set(child.id, [child])
      sizes.set(child.id, sizeOf(child, cardSize))
      continue
    }

    const id = '\0run:' + child.id
    const runGrid = grid(
      run.map((node) => sizeOf(node, cardSize)),
      Math.min(WRAP, Math.ceil(Math.sqrt(run.length))),
      gap.node,
    )

    run.forEach((member, i) => {
      unitOf.set(member.id, id)
      offsetOf.set(member.id, runGrid.at[i])
    })
    members.set(id, run)
    sizes.set(id, { width: runGrid.width, height: runGrid.height })
  }

  const seen = new Set<string>()
  const unitEdges: Edge[] = []

  for (const [source, target] of edges) {
    const edge: Edge = [unitOf.get(source)!, unitOf.get(target)!]

    if (edge[0] === edge[1] || seen.has(edge.join('>'))) continue

    seen.add(edge.join('>'))
    unitEdges.push(edge)
  }

  const linked = new Set(unitEdges.flat())
  const roots = linkRoots([...linked], unitEdges)
  const linkedBoxes = unitEdges.length
    ? await elkBoxes(
        [...linked].map((id) => ({ id, ...sizes.get(id)! })),
        unitEdges,
        gap,
      )
    : new Map<string, Box>()
  const parts = new Map<string, Map<string, Box>>()

  for (const id of linked) {
    const root = roots.get(id)!
    const part = parts.get(root) ?? new Map<string, Box>()

    part.set(id, linkedBoxes.get(id)!)
    parts.set(root, part)
  }

  const earliest = (ids: string[]) => ids.flatMap((id) => members.get(id)!).reduce((first, node) => (reading(node, first) < 0 ? node : first))

  const shapes: Shape[] = []
  const clusterOf = (ids: string[]) =>
    mostCommon(ids.flatMap((id) => members.get(id)!.flatMap((member) => (outside.has(member.id) ? [outside.get(member.id)!] : []))))

  for (const part of parts.values()) {
    const ids = [...part.keys()]

    shapes.push({ ids, first: earliest(ids), ...frameBlock(part, gap.layer), isLinked: true, cluster: clusterOf(ids) })
  }

  for (const id of members.keys()) {
    if (linked.has(id)) continue

    const size = sizes.get(id)!

    shapes.push({
      ids: [id],
      first: earliest([id]),
      boxes: new Map([[id, { x: 0, y: 0, ...size }]]),
      size,
      isLinked: false,
      cluster: clusterOf([id]),
    })
  }

  shapes.sort((a, b) => reading(a.first, b.first))

  const group = (list: Shape[]) => {
    const byCluster = new Map<string, Shape[]>()

    for (const shape of list) byCluster.set(shape.cluster, [...(byCluster.get(shape.cluster) ?? []), shape])

    return byCluster
  }

  const cardCount = (list: Shape[]) => list.reduce((sum, shape) => sum + shape.ids.reduce((count, id) => count + members.get(id)!.length, 0), 0)

  // A tie shared by only a card or two doesn't read as a patch of its own, so those cards join the rest.
  for (const [cluster, list] of group(shapes)) if (cluster && cardCount(list) < CLUSTER_MINIMUM) for (const shape of list) shape.cluster = ''

  const rowWidth = Math.max(ROW_WIDTH, ...shapes.filter((shape) => shape.isLinked).map((shape) => shape.size.width))

  // Lays out one cluster as a block: its linked blocks fill rows left to right, and its loose siblings follow in a grid.
  const arrangeCluster = (clusterShapes: Shape[]): { at: Map<Shape, Point>; size: Size } => {
    const at = new Map<Shape, Point>()
    let x = 0
    let top = 0
    let rowHeight = 0

    for (const shape of clusterShapes.filter((member) => member.isLinked)) {
      if (x > 0 && x + shape.size.width > rowWidth) {
        top += rowHeight + gap.component
        x = 0
        rowHeight = 0
      }

      at.set(shape, { x, y: top })
      x += shape.size.width + gap.component
      rowHeight = Math.max(rowHeight, shape.size.height)
    }

    if (rowHeight) top += rowHeight + gap.component

    const loose = clusterShapes.filter((member) => !member.isLinked)
    const looseGrid = grid(
      loose.map((shape) => shape.size),
      Math.ceil(Math.sqrt(loose.length)),
      gap.component,
    )

    loose.forEach((shape, i) => at.set(shape, { x: looseGrid.at[i].x, y: top + looseGrid.at[i].y }))

    const frame = bounds([...at].map(([shape, point]) => ({ ...point, ...shape.size })))

    return { at, size: { width: frame.x + frame.width, height: frame.y + frame.height } }
  }

  // Clusters sit side by side and wrap at the row width, with a wider gap between them than inside them.
  const clusterGap = gap.component * 2
  const placed = new Map<Shape, Point>()
  let x = 0
  let top = 0
  let rowHeight = 0

  for (const block of [...group(shapes).values()].map(arrangeCluster)) {
    if (x > 0 && x + block.size.width > rowWidth) {
      top += rowHeight + clusterGap
      x = 0
      rowHeight = 0
    }

    for (const [shape, point] of block.at) placed.set(shape, { x: x + point.x, y: top + point.y })

    x += block.size.width + clusterGap
    rowHeight = Math.max(rowHeight, block.size.height)
  }

  const positions = new Map<string, Point>()

  for (const [shape, at] of placed) {
    for (const id of shape.ids) {
      const box = shape.boxes.get(id)!

      for (const member of members.get(id)!) {
        const offset = offsetOf.get(member.id) ?? { x: 0, y: 0 }

        positions.set(member.id, { x: at.x + box.x + offset.x, y: at.y + box.y + offset.y })
      }
    }
  }

  return positions
}

/**
 * The groups waiting for layout, deepest first. A group is arranged only after every group inside it has settled at
 * its final size, so a single pass over this order lays out the whole tree. Groups at the same depth keep node order.
 */
export function layoutOrder(nodes: AppNode[]): AppNode[] {
  const marked = nodes.filter((node) => isCluster(node) && node.data.layout)

  if (!marked.length) return marked

  const nodeMap = byId(nodes)
  const depth = new Map(marked.map((node) => [node.id, ancestors(node.id, nodeMap).length]))

  return marked.sort((a, b) => depth.get(b.id)! - depth.get(a.id)!)
}

/**
 * Lays out the direct children of one group (or the top level when `groupId` is undefined) the way the group asks
 * to be arranged. Links between deeper descendants are lifted to the child that contains them, so nested groups are
 * placed as single boxes.
 */
export async function reflow(
  nodes: AppNode[],
  links: Link[],
  groupId: string | undefined,
  cardSize: CardSize = { width: TASK_WIDTH, height: TASK_HEIGHT },
): Promise<AppNode[]> {
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
  const reaches = new Map<string, string[]>()

  for (const link of links) {
    const source = lift(link.from)
    const target = lift(link.to)

    // A link of any kind to work outside the group pulls the child toward others tied to the same place.
    if (groupId && (source === null) !== (target === null)) {
      const [inside, away] = source ? [source, nodeMap.get(link.to)] : [target!, nodeMap.get(link.from)]

      if (away) reaches.set(inside, [...(reaches.get(inside) ?? []), away.parentId ?? ''])
    }

    if (link.kind !== 'blocks') continue

    if (!source || !target || source === target || seen.has(source + '>' + target)) continue

    seen.add(source + '>' + target)
    edges.push([source, target])
  }

  const outside = new Map([...reaches].map(([id, places]) => [id, mostCommon(places)]))
  const positions = await flow(children, edges, groupId ? INNER_GAP : TOP_GAP, cardSize, outside)
  const offset = groupId ? { x: GROUP_PADDING, y: GROUP_HEADER_HEIGHT } : { x: 0, y: 0 }

  return normalize(
    nodes.map((node) => {
      const position = positions.get(node.id)

      return position ? { ...node, position: { x: position.x + offset.x, y: position.y + offset.y } } : node
    }),
    cardSize,
  )
}
