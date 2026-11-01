import type { Point } from './types'

const CORNER_RADIUS = 8

/** An SVG path through orthogonal points, with each corner rounded so a turn reads as one line, not two. */
export function roundedPath(points: Point[]): string {
  const clean = points.filter((point, i) => i === 0 || point.x !== points[i - 1].x || point.y !== points[i - 1].y)

  if (clean.length < 2) return ''

  let d = `M${clean[0].x},${clean[0].y}`

  for (let i = 1; i < clean.length - 1; i++) {
    const previous = clean[i - 1]
    const corner = clean[i]
    const next = clean[i + 1]
    const before = Math.hypot(corner.x - previous.x, corner.y - previous.y)
    const after = Math.hypot(next.x - corner.x, next.y - corner.y)
    const radius = Math.min(CORNER_RADIUS, before / 2, after / 2)
    const inX = corner.x - ((corner.x - previous.x) / (before || 1)) * radius
    const inY = corner.y - ((corner.y - previous.y) / (before || 1)) * radius
    const outX = corner.x + ((next.x - corner.x) / (after || 1)) * radius
    const outY = corner.y + ((next.y - corner.y) / (after || 1)) * radius

    d += ` L${inX},${inY} Q${corner.x},${corner.y} ${outX},${outY}`
  }

  const last = clean[clean.length - 1]

  return d + ` L${last.x},${last.y}`
}
