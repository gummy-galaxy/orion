import { GAP, GROUP_HEADER_HEIGHT, GROUP_PADDING, TASK_HEIGHT, TASK_WIDTH } from './geometry'
import ELK from 'elkjs/lib/elk.bundled.js'
import { indexNodes } from './hierarchy/indexNodes'
import {
  absolutePosition,
  ancestors,
  byId,
  groupHeaderHeight,
  isCluster,
  normalize,
  pruneEmptied,
  sizeOf,
  type AppNode,
  type ClusterNode,
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
/** A link between two laid-out boxes, with the label it's drawn with, if any. */
type Edge = [string, string, string?]

const INNER_GAP: Gap = { node: GAP.inner.y, layer: GAP.inner.x, component: GAP.inner.component }
const TOP_GAP: Gap = { node: GAP.top.y, layer: GAP.top.x, component: GAP.top.component }

const elkOptions = (gap: Gap) => ({
  'elk.algorithm': 'layered',
  'elk.direction': 'RIGHT',
  'elk.spacing.nodeNode': String(gap.node),
  'elk.layered.spacing.nodeNodeBetweenLayers': String(gap.layer),
  'elk.spacing.componentComponent': String(gap.component),
  'elk.edgeLabels.placement': 'CENTER',
})

/** About how much room a link's label takes on the canvas: 11px monospace text in a tag with 6px sides. */
export const LABEL_SIZE = { character: 6.6, padding: 12, height: 18 }

export function labelWidth(text: string): number {
  return Math.ceil(text.length * LABEL_SIZE.character) + LABEL_SIZE.padding
}

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
 * layer is wider on its own, and stacks them top to bottom, so a long chain reads like lines of text. A `rowWidth`
 * replaces both limits, as when a person sized the group. Returns null when the layout already fits.
 */
export function wrapLayers(boxes: Map<string, Box>, gap: number, rowWidth?: number): Map<string, Box> | null {
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

    const fits =
      rowWidth === undefined ? strip && strip.length < WRAP && layer.right - strip[0].x <= ROW_WIDTH : strip && layer.right - strip[0].x <= rowWidth

    if (strip && fits) strip.push(layer)
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
    // Labels make ELK leave room for them between the boxes they join.
    edges: edges.map(([source, target, label]) => ({
      id: source + '>' + target,
      sources: [source],
      targets: [target],
      labels: label ? [{ id: source + '>' + target + ':label', text: label, width: labelWidth(label), height: LABEL_SIZE.height }] : [],
    })),
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
function frameBlock(boxes: Map<string, Box>, gap: number, rowWidth?: number): { boxes: Map<string, Box>; size: Size } {
  const wrapped = wrapLayers(boxes, gap, rowWidth) ?? boxes
  const frame = bounds([...wrapped.values()])

  return {
    boxes: new Map([...wrapped].map(([id, box]) => [id, { ...box, x: box.x - frame.x, y: box.y - frame.y }])),
    size: { width: frame.width, height: frame.height },
  }
}

/** Where a flow puts each child, and the size of what it laid out. */
type Arrangement = { positions: Map<string, Point> } & Size

/** The most columns, at least one, that keep a grid of `sizes` within `maxWidth`. */
function columnsWithin(sizes: Size[], maxWidth: number, gap: number): number {
  for (let columns = sizes.length; columns > 1; columns--) if (grid(sizes, columns, gap).width <= maxWidth) return columns

  return 1
}

/**
 * The default flow. Siblings that link to each other form a block, laid out by ELK's layered algorithm with two
 * limits on width: a run of more than `WRAP` interchangeable siblings is laid out as a grid of its own, and chains
 * longer than `WRAP` steps wrap onto further rows. Every block and every sibling with no links then goes into one
 * grid, in reading order, so unrelated pieces line up in rows and columns.
 *
 * ELK runs once, here. The arrangement it returns places the blocks for a width: without one, the grid's columns
 * follow the square root of its count; with one, chains wrap and the grid takes as many columns as fit in it. That
 * part is quick, so a resize can try widths as it goes.
 */
async function planFlow(children: AppNode[], edges: Edge[], gap: Gap, cardSize: CardSize): Promise<(maxWidth?: number) => Arrangement> {
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

  for (const [source, target, label] of edges) {
    const edge: Edge = [unitOf.get(source)!, unitOf.get(target)!]
    const key = edge.join('>')

    if (edge[0] === edge[1] || seen.has(key)) continue

    // A label only makes room between the two boxes it's drawn between, not around a grid of siblings.
    if (label && edge[0] === source && edge[1] === target) edge.push(label)

    seen.add(key)
    unitEdges.push(edge)
  }

  const linked = new Set(unitEdges.flatMap(([source, target]) => [source, target]))
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
  const blocks = [...parts.values()].map((part) => ({ ids: [...part.keys()], first: earliest([...part.keys()]), part }))
  const singles: { ids: string[]; first: AppNode; boxes: Map<string, Box>; size: Size }[] = []

  for (const id of members.keys()) {
    if (linked.has(id)) continue

    const size = sizes.get(id)!

    singles.push({ ids: [id], first: earliest([id]), boxes: new Map([[id, { x: 0, y: 0, ...size }]]), size })
  }

  return (maxWidth) => {
    const shapes = [...blocks.map((block) => ({ ids: block.ids, first: block.first, ...frameBlock(block.part, gap.layer, maxWidth) })), ...singles]

    shapes.sort((a, b) => reading(a.first, b.first))

    const shapeSizes = shapes.map((shape) => shape.size)
    const laidOut = grid(
      shapeSizes,
      maxWidth === undefined ? Math.ceil(Math.sqrt(shapes.length)) : columnsWithin(shapeSizes, maxWidth, gap.component),
      gap.component,
    )
    const positions = new Map<string, Point>()

    shapes.forEach((shape, i) => {
      for (const id of shape.ids) {
        const box = shape.boxes.get(id)!

        for (const member of members.get(id)!) {
          const offset = offsetOf.get(member.id) ?? { x: 0, y: 0 }

          positions.set(member.id, {
            x: laidOut.at[i].x + box.x + offset.x,
            y: laidOut.at[i].y + box.y + offset.y,
          })
        }
      }
    })

    return { positions, width: laidOut.width, height: laidOut.height }
  }
}

/**
 * The groups waiting for layout, deepest first. A group is arranged only after every group inside it has settled at
 * its final size, so a single pass over this order lays out the whole tree. Groups at the same depth keep node order.
 */
export function layoutOrder(nodes: AppNode[]): AppNode[] {
  const marked = nodes.filter((node) => isCluster(node) && node.data.layout)

  if (!marked.length) return marked

  const { depth } = indexNodes(nodes)

  return marked.sort((a, b) => depth.get(b.id)! - depth.get(a.id)!)
}

/**
 * A group's layout, worked out once and placed for any width. `measure` gives the size the group would take with its
 * contents laid out within `maxWidth`, and `place` lays them out that way. At the top level the size is the contents'.
 * `sameLayout` tells whether two widths put every child in the same place.
 */
export type ReflowPlan = {
  measure: (maxWidth?: number) => Size
  place: (maxWidth?: number) => AppNode[]
  sameLayout: (first: number | undefined, second: number | undefined) => boolean
}

/**
 * Plans the layout of the direct children of one group (or the top level when `groupId` is undefined) the way the
 * group asks to be arranged. Links between deeper descendants are lifted to the child that contains them, so nested
 * groups are placed as single boxes. Returns null for a custom group or one with nothing in it.
 */
export async function planReflow(
  nodes: AppNode[],
  links: Link[],
  groupId: string | undefined,
  cardSize: CardSize = { width: TASK_WIDTH, height: TASK_HEIGHT },
): Promise<ReflowPlan | null> {
  const nodeMap = byId(nodes)
  const group = groupId ? nodeMap.get(groupId) : undefined
  const arrange = group && isCluster(group) ? (group.data.arrange ?? 'auto') : 'auto'

  if (arrange === 'custom') return null

  const children = nodes.filter((node) => node.parentId === groupId)

  if (!children.length) return null

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

  for (const link of links) {
    if (link.kind !== 'blocks') continue

    const source = lift(link.from)
    const target = lift(link.to)

    if (!source || !target || source === target || seen.has(source + '>' + target)) continue

    seen.add(source + '>' + target)
    // Only a link drawn directly between the two shows its label; lifted links are bundled.
    edges.push(source === link.from && target === link.to && link.label ? [source, target, link.label] : [source, target])
  }

  const arrangeFor = await planFlow(children, edges, groupId ? INNER_GAP : TOP_GAP, cardSize)
  const offset = groupId ? { x: GROUP_PADDING, y: groupHeaderHeight(group && isCluster(group) ? group.data : undefined) } : { x: 0, y: 0 }
  const measured = new Map<number | undefined, Arrangement>()

  const arrangement = (maxWidth?: number) => {
    const known = measured.get(maxWidth)

    if (known) return known

    const fresh = arrangeFor(maxWidth)

    measured.set(maxWidth, fresh)

    return fresh
  }

  return {
    measure: (maxWidth) => {
      const { width, height } = arrangement(maxWidth)

      return groupId ? { width: width + GROUP_PADDING * 2, height: height + offset.y + GROUP_PADDING } : { width, height }
    },
    sameLayout: (first, second) => {
      const a = arrangement(first).positions
      const b = arrangement(second).positions

      return [...a].every(([id, point]) => b.get(id)?.x === point.x && b.get(id)?.y === point.y)
    },
    place: (maxWidth) => {
      const { positions } = arrangement(maxWidth)

      return normalize(
        nodes.map((node) => {
          const position = positions.get(node.id)

          return position ? { ...node, position: { x: position.x + offset.x, y: position.y + offset.y } } : node
        }),
        cardSize,
      )
    },
  }
}

/** The widest a group with a size lets its contents run. */
export function sizedWidth(group: AppNode | undefined): number | undefined {
  const size = group && isCluster(group) ? group.data.size : undefined

  return size ? size.width - GROUP_PADDING * 2 : undefined
}

/** Lays out the direct children of one group, or the top level, as `planReflow` plans them, within the group's size. */
export async function reflow(
  nodes: AppNode[],
  links: Link[],
  groupId: string | undefined,
  cardSize: CardSize = { width: TASK_WIDTH, height: TASK_HEIGHT },
): Promise<AppNode[]> {
  const plan = await planReflow(nodes, links, groupId, cardSize)

  return plan ? plan.place(sizedWidth(groupId ? nodes.find((node) => node.id === groupId) : undefined)) : nodes
}

// Group changes show at once with this geometry. Which items belong to a group is the server's rule, applied through operations.
/** Wraps the selection in a new group under the selection's nearest shared parent. */
export function groupSelection(
  nodes: AppNode[],
  cardSize: CardSize = { width: TASK_WIDTH, height: TASK_HEIGHT },
): { nodes: AppNode[]; groupId: string } | null {
  const nodeMap = byId(nodes)
  const selection = nodes.filter(
    (node) => node.selected && !node.hidden && !ancestors(node.id, nodeMap).some((ancestor) => nodeMap.get(ancestor)?.selected),
  )

  if (!selection.length) return null

  const chains = selection.map((node) => ancestors(node.id, nodeMap))
  const parent = chains[0].find((ancestor) => chains.every((chain) => chain.includes(ancestor)))
  const parentNode = parent ? nodeMap.get(parent) : undefined
  const origin = parentNode ? absolutePosition(parentNode, nodeMap) : { x: 0, y: 0 }
  const absolutePositions = new Map(selection.map((node) => [node.id, absolutePosition(node, nodeMap)]))
  const minX = Math.min(...[...absolutePositions.values()].map((position) => position.x))
  const minY = Math.min(...[...absolutePositions.values()].map((position) => position.y))
  const groupPosition = { x: minX - origin.x - GROUP_PADDING, y: minY - origin.y - GROUP_HEADER_HEIGHT }
  const groupId = 'g-' + Date.now().toString(36)
  const group: ClusterNode = {
    id: groupId,
    type: 'cluster',
    position: groupPosition,
    parentId: parent,
    data: { kind: 'cluster', label: 'New group' },
    selected: true,
  }
  const next = nodes.map((node): AppNode => {
    const position = absolutePositions.get(node.id)

    if (position)
      return {
        ...node,
        parentId: groupId,
        selected: false,
        position: { x: position.x - origin.x - groupPosition.x, y: position.y - origin.y - groupPosition.y },
      }

    return node.selected ? { ...node, selected: false } : node
  })

  return { nodes: normalize([...next, group], cardSize), groupId }
}

/** Dissolves the given groups, handing their children to the group's parent in place. */
export function ungroup(nodes: AppNode[], ids: string[], cardSize: CardSize = { width: TASK_WIDTH, height: TASK_HEIGHT }): AppNode[] {
  let next = nodes

  for (const id of ids) {
    const group = next.find((node) => node.id === id)

    if (!group || !isCluster(group)) continue

    next = next
      .filter((node) => node.id !== id)
      .map((node): AppNode =>
        node.parentId === id
          ? {
              ...node,
              parentId: group.parentId,
              selected: true,
              position: { x: node.position.x + group.position.x, y: node.position.y + group.position.y },
            }
          : node,
      )
  }

  return pruneEmptied(nodes, normalize(next, cardSize))
}

/**
 * The first spot at or below `preferred` that no sibling overlaps, `gap` below any in the way, so a moved group keeps its
 * place when it's free.
 */
function freeSpotBelow(
  siblings: AppNode[],
  preferred: { x: number; y: number },
  size: { width: number; height: number },
  gap: number,
  cardSize: CardSize,
) {
  const spot = { ...preferred }

  const clashes = (sibling: AppNode) => {
    const siblingSize = sizeOf(sibling, cardSize)

    return (
      spot.x < sibling.position.x + siblingSize.width &&
      sibling.position.x < spot.x + size.width &&
      spot.y < sibling.position.y + siblingSize.height &&
      sibling.position.y < spot.y + size.height
    )
  }

  let clash = siblings.find(clashes)

  while (clash) {
    spot.y = clash.position.y + sizeOf(clash, cardSize).height + gap
    clash = siblings.find(clashes)
  }

  return spot
}

/**
 * Lifts a group out of its parent to the parent's level, at the first free spot at or below where it was, so it stays
 * where it was on screen when nothing covers it. The parent shrinks or grows to fit what remains. Anything else returns
 * the nodes unchanged.
 */
export function moveOutOfGroup(nodes: AppNode[], id: string, cardSize: CardSize = { width: TASK_WIDTH, height: TASK_HEIGHT }): AppNode[] {
  const nodeMap = byId(nodes)
  const group = nodeMap.get(id)

  if (!group || !isCluster(group) || !group.parentId) return nodes

  const parent = nodeMap.get(group.parentId)
  const grandparent = parent?.parentId ? nodeMap.get(parent.parentId) : undefined
  const origin = grandparent ? absolutePosition(grandparent, nodeMap) : { x: 0, y: 0 }
  const absolute = absolutePosition(group, nodeMap)
  // Fitting first lets the old parent shrink to what remains, so the spot is checked against where it will actually be.
  const lifted = pruneEmptied(
    nodes,
    normalize(
      nodes.map((node) =>
        node.id === id ? { ...node, parentId: grandparent?.id, position: { x: absolute.x - origin.x, y: absolute.y - origin.y } } : node,
      ),
      cardSize,
    ),
  )
  const landed = lifted.find((node) => node.id === id)

  if (!landed) return lifted

  const siblings = lifted.filter((node) => node.parentId === landed.parentId && node.id !== id)
  const position = freeSpotBelow(siblings, landed.position, sizeOf(landed, cardSize), (grandparent ? GAP.inner : GAP.top).component, cardSize)

  return normalize(
    lifted.map((node) => (node.id === id ? { ...node, position } : node)),
    cardSize,
  )
}
