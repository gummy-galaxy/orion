import type { Box, Point, ResizeEdges, Size } from './types'

/**
 * The box a resize asks for: `start` with the edges being dragged moved by `delta`. It stays at least `minimum` in
 * size, and the edges that aren't dragged hold still.
 */
export function resizeBox(start: Box, edges: ResizeEdges, delta: Point, minimum: Size): Box {
  const box = { ...start }

  if (edges.right) box.width = Math.max(minimum.width, start.width + delta.x)

  if (edges.left) {
    box.width = Math.max(minimum.width, start.width - delta.x)
    box.x = start.x + start.width - box.width
  }

  if (edges.bottom) box.height = Math.max(minimum.height, start.height + delta.y)

  if (edges.top) {
    box.height = Math.max(minimum.height, start.height - delta.y)
    box.y = start.y + start.height - box.height
  }

  return box
}
