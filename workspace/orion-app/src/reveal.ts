import type { Viewport } from '@xyflow/react'
import type { CardSize } from './cardSize'
import { detailLevels, shownLevel, type Detail } from './detail'
import { absolutePosition, ancestors, byId, isCluster, sizeOf, type AppNode } from './model'
import { MIN_ZOOM } from './viewport'

export type Bounds = { x: number; y: number; width: number; height: number }

/** The innermost group that holds every id, or null for the top level. A group doesn't hold itself. */
export function revealRoot(nodes: AppNode[], ids: string[]): string | null {
  const nodeMap = byId(nodes)
  const chains = ids.map((id) => ancestors(id, nodeMap))
  const [first = [], ...rest] = chains

  return first.find((group) => rest.every((chain) => chain.includes(group))) ?? null
}

/** How many groups lie between an id and the open group, or from the top level when `root` is null. */
function groupsBelow(id: string, root: string | null, nodeMap: Map<string, AppNode>): number {
  const chain = ancestors(id, nodeMap)

  return root ? chain.indexOf(root) : chain.length
}

/**
 * The detail that shows every id under `root`. Detail only ever grows here, since a reveal shouldn't fold
 * back up what the reader opened, and it's left alone when it already shows them.
 */
export function revealDetail(nodes: AppNode[], root: string | null, ids: string[], detail: Detail): Detail {
  const nodeMap = byId(nodes)
  const inRoot = (id: string) => !root || id === root || ancestors(id, nodeMap).includes(root)
  const depths = nodes
    .filter((node) => isCluster(node) && node.id !== root && inRoot(node.id))
    .map((node) => groupsBelow(node.id, root, nodeMap))
  const levels = detailLevels(depths)
  // Each group an id sits inside has to stay open, so the level must be one past the deepest of them.
  const needed = Math.max(0, ...ids.map((id) => groupsBelow(id, root, nodeMap))) + 1

  if (shownLevel(detail, levels) >= needed) return detail

  return needed >= levels ? null : needed
}

/** The box around the ids in flow coordinates, or null when none of them is on the canvas. */
export function revealBounds(nodes: AppNode[], ids: string[], cardSize: CardSize): Bounds | null {
  const nodeMap = byId(nodes)
  let x0 = Infinity
  let y0 = Infinity
  let x1 = -Infinity
  let y1 = -Infinity

  for (const id of ids) {
    const node = nodeMap.get(id)

    if (!node) continue

    const position = absolutePosition(node, nodeMap)
    const size = sizeOf(node, cardSize)

    x0 = Math.min(x0, position.x)
    y0 = Math.min(y0, position.y)
    x1 = Math.max(x1, position.x + size.width)
    y1 = Math.max(y1, position.y + size.height)
  }

  if (!Number.isFinite(x0)) return null

  return { x: x0, y: y0, width: x1 - x0, height: y1 - y0 }
}

/**
 * The camera that centers `bounds` in a `box` of screen pixels, leaving `padding` (a fraction of each side) around
 * it. It zooms in only as far as `maxZoom`, so a single small card doesn't fill the screen.
 */
export function framedViewport(
  bounds: Bounds,
  box: { width: number; height: number },
  { padding, maxZoom }: { padding: number; maxZoom: number },
): Viewport {
  const width = Math.max(bounds.width, 1)
  const height = Math.max(bounds.height, 1)
  const fit = Math.min(maxZoom, (box.width * (1 - padding * 2)) / width, (box.height * (1 - padding * 2)) / height)
  const zoom = Math.max(MIN_ZOOM, fit)

  return {
    x: box.width / 2 - (bounds.x + width / 2) * zoom,
    y: box.height / 2 - (bounds.y + height / 2) * zoom,
    zoom,
  }
}
