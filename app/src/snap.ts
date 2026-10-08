import { GAP } from './layout'
import { absolutePosition, byId, sizeOf, type AppNode } from './model'

type Axis = 'x' | 'y'
type Box = { x: number; y: number; width: number; height: number }
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

const start = (box: Box, axis: Axis) => (axis === 'x' ? box.x : box.y)
const length = (box: Box, axis: Axis) => (axis === 'x' ? box.width : box.height)
const end = (box: Box, axis: Axis) => start(box, axis) + length(box, axis)
const center = (box: Box, axis: Axis) => start(box, axis) + length(box, axis) / 2
const otherAxis = (axis: Axis): Axis => (axis === 'x' ? 'y' : 'x')
/** Whether two boxes cover some of the same span along `axis`. */
const sharesSpan = (first: Box, second: Box, axis: Axis) => start(first, axis) < end(second, axis) && start(second, axis) < end(first, axis)
const intersects = (first: Box, second: Box) => sharesSpan(first, second, 'x') && sharesSpan(first, second, 'y')
const separation = (first: Box, second: Box, axis: Axis) =>
  Math.max(0, start(second, axis) - end(first, axis), start(first, axis) - end(second, axis))
const overlap = (first: Box, second: Box, axis: Axis) =>
  Math.max(0, Math.min(end(first, axis), end(second, axis)) - Math.max(start(first, axis), start(second, axis)))

type Hit = { offset: number; guide: Guide }
type Scene = { moving: Box; others: Box[]; gaps: Record<Axis, number[]> }

/** Spacing neighbors already keep along `axis`, most common first. */
function spacing(boxes: Box[], axis: Axis): number[] {
  const counts = new Map<number, number>()
  for (const box of boxes) {
    let nearest = Infinity
    for (const otherBox of boxes) {
      const gap = start(otherBox, axis) - end(box, axis)
      if (otherBox !== box && sharesSpan(box, otherBox, otherAxis(axis)) && gap > 0 && gap < nearest) nearest = gap
    }
    if (nearest <= MAX_GAP) counts.set(Math.round(nearest), (counts.get(Math.round(nearest)) ?? 0) + 1)
  }
  return [...counts].sort((a, b) => b[1] - a[1]).map(([gap]) => gap)
}

/** The dragged nodes as one box, and their siblings, in canvas coordinates. */
function scene(nodes: AppNode[], ids: string[]): Scene | null {
  const nodeMap = byId(nodes)
  const movedNodes = ids.map((id) => nodeMap.get(id)).filter((node) => !!node)
  if (!movedNodes.length) return null
  const boxOf = (node: AppNode): Box => ({ ...absolutePosition(node, nodeMap), ...sizeOf(node) })
  const boxes = movedNodes.map(boxOf)
  const x = Math.min(...boxes.map((box) => box.x))
  const y = Math.min(...boxes.map((box) => box.y))
  const moving = {
    x,
    y,
    width: Math.max(...boxes.map((box) => box.x + box.width)) - x,
    height: Math.max(...boxes.map((box) => box.y + box.height)) - y,
  }
  const parent = movedNodes[0].parentId
  const movedIds = new Set(ids)
  const others = nodes.filter((node) => node.parentId === parent && !movedIds.has(node.id)).map(boxOf)
  const fallback = parent ? GAP.inner : GAP.top
  const gapsForAxis = (axis: Axis) => [...new Set([...spacing(others, axis).slice(0, 2), fallback[axis]])]
  return { moving, others, gaps: { x: gapsForAxis('x'), y: gapsForAxis('y') } }
}

/** Every edge, center, and spacing within `tolerance` of the moving box along `axis`. */
function hits({ moving, others, gaps }: Scene, axis: Axis, tolerance: number): Hit[] {
  const perpendicular = otherAxis(axis)
  const matches: Hit[] = []
  const addHit = (offset: number, guide: Guide) => Math.abs(offset) <= tolerance && matches.push({ offset, guide })
  for (const otherBox of others) {
    const beside = sharesSpan(moving, otherBox, perpendicular)
    const from = Math.min(start(moving, perpendicular), start(otherBox, perpendicular))
    const to = Math.max(end(moving, perpendicular), end(otherBox, perpendicular))
    const pairs = [
      [start(moving, axis), start(otherBox, axis)],
      [end(moving, axis), end(otherBox, axis)],
      [center(moving, axis), center(otherBox, axis)],
    ]
    // Side by side, meeting edges would mean touching; elsewhere they make a column.
    if (!beside) pairs.push([start(moving, axis), end(otherBox, axis)], [end(moving, axis), start(otherBox, axis)])
    for (const [edge, at] of pairs) addHit(at - edge, { kind: 'line', axis, at, from, to })
    if (!beside) continue
    const at = Math.max(start(moving, perpendicular), start(otherBox, perpendicular)) + overlap(moving, otherBox, perpendicular) / 2
    for (const gap of gaps[axis]) {
      addHit(end(otherBox, axis) + gap - start(moving, axis), {
        kind: 'gap',
        axis,
        at,
        from: end(otherBox, axis),
        to: end(otherBox, axis) + gap,
      })
      addHit(start(otherBox, axis) - gap - end(moving, axis), {
        kind: 'gap',
        axis,
        at,
        from: start(otherBox, axis) - gap,
        to: start(otherBox, axis),
      })
    }
  }
  return matches
}

function shift(nodes: AppNode[], ids: string[], deltaX: number, deltaY: number): AppNode[] {
  const movedIds = new Set(ids)
  return nodes.map((node) => (movedIds.has(node.id) ? { ...node, position: { x: node.position.x + deltaX, y: node.position.y + deltaY } } : node))
}

/**
 * Pulls dragged nodes onto nearby edges, centers, and the spacing their siblings use.
 * Each pull only holds within `tolerance` (canvas units), so dragging on slides past it.
 */
export function snapDrag(nodes: AppNode[], ids: string[], tolerance: number): AppNode[] {
  const currentScene = scene(nodes, ids)
  if (!currentScene) return nodes
  const pull = (axis: Axis) =>
    hits(currentScene, axis, tolerance).reduce<Hit | null>(
      (best, candidate) => (!best || Math.abs(candidate.offset) < Math.abs(best.offset) ? candidate : best),
      null,
    )?.offset ?? 0
  const deltaX = pull('x')
  const deltaY = pull('y')
  return deltaX || deltaY ? shift(nodes, ids, deltaX, deltaY) : nodes
}

/** Guides for whatever the nodes being dragged now line up with. */
export function snapGuides(nodes: AppNode[]): Guide[] {
  const ids = nodes.filter((node) => node.dragging).map((node) => node.id)
  const currentScene = ids.length ? scene(nodes, ids) : null
  if (!currentScene) return []
  const lines = new Map<string, Guide>()
  for (const axis of ['x', 'y'] as const)
    for (const { guide } of hits(currentScene, axis, 0.5)) {
      const key = guide.kind === 'line' ? `${axis}:${Math.round(guide.at)}` : `${axis}:${guide.from}:${guide.to}:${guide.at}`
      const previous = lines.get(key)
      lines.set(key, previous ? { ...previous, from: Math.min(previous.from, guide.from), to: Math.max(previous.to, guide.to) } : guide)
    }
  return [...lines.values()]
}

/**
 * Where a drop settles. Landing on a sibling, or throwing a node quickly beside one,
 * moves it to the nearest open cell of that sibling's grid. Returns null to stay put.
 */
export function settleDrop(nodes: AppNode[], ids: string[], thrown: boolean): AppNode[] | null {
  const currentScene = scene(nodes, ids)
  if (!currentScene) return null
  const { moving, others } = currentScene
  const gap = { x: currentScene.gaps.x[0], y: currentScene.gaps.y[0] }
  const reach = Math.max(gap.x, gap.y) * 2
  const intersectionArea = (otherBox: Box) => overlap(moving, otherBox, 'x') * overlap(moving, otherBox, 'y')
  const distance = (otherBox: Box) => Math.hypot(separation(moving, otherBox, 'x'), separation(moving, otherBox, 'y'))
  const landed = others.filter((otherBox) => intersects(moving, otherBox)).sort((a, b) => intersectionArea(b) - intersectionArea(a))[0]
  const anchor =
    landed ?? (thrown ? others.filter((otherBox) => distance(otherBox) <= reach).sort((a, b) => distance(a) - distance(b))[0] : undefined)
  if (!anchor) return null

  // The anchor's columns and rows, lined up by either edge so different sizes still fit.
  const xPositions: number[] = []
  const yPositions: number[] = []
  for (let i = -RINGS; i <= RINGS; i++) {
    xPositions.push(anchor.x + i * (anchor.width + gap.x), anchor.x + anchor.width - moving.width + i * (anchor.width + gap.x))
    yPositions.push(anchor.y + i * (anchor.height + gap.y), anchor.y + anchor.height - moving.height + i * (anchor.height + gap.y))
  }
  const clearance = Math.min(gap.x, gap.y) / 2
  let best: { x: number; y: number; distance: number } | null = null
  for (const x of xPositions)
    for (const y of yPositions) {
      const room = { x: x - clearance, y: y - clearance, width: moving.width + clearance * 2, height: moving.height + clearance * 2 }
      if (others.some((otherBox) => intersects(room, otherBox))) continue
      const distance = Math.hypot(x - moving.x, y - moving.y)
      if (!best || distance < best.distance) best = { x, y, distance }
    }
  if (!best || best.distance < 0.5 || (!landed && best.distance > reach)) return null
  return shift(nodes, ids, best.x - moving.x, best.y - moving.y)
}

/** Restore arranged children after a drag, then settle only freely positioned nodes. */
export function finishDrag(
  nodes: AppNode[],
  origins: ReadonlyMap<string, AppNode['position']>,
  ids: string[],
  free: boolean,
  thrown: boolean,
): AppNode[] {
  const restored = origins.size ? nodes.map((node) => (origins.has(node.id) ? { ...node, position: origins.get(node.id)! } : node)) : nodes
  const movableIds = ids.filter((id) => !origins.has(id))
  return free || !movableIds.length ? restored : (settleDrop(restored, movableIds, thrown) ?? restored)
}
