import type { Point } from './types'

/** The path `CurveEdge` draws today, copied so the baseline matches the app line for line. */
export function curvePath(source: Point, target: Point): string {
  const reach = Math.min(80, Math.max(36, Math.abs(target.y - source.y) / 3))

  if (target.x >= source.x - 24) {
    const bend = Math.max(Math.abs(target.x - source.x) / 2, reach)

    return `M${source.x},${source.y} C${source.x + bend},${source.y} ${target.x - bend},${target.y} ${target.x},${target.y}`
  }

  const midY = Math.abs(target.y - source.y) < 60 ? Math.max(source.y, target.y) + 60 : (source.y + target.y) / 2
  const midX = (source.x + target.x) / 2
  const approach = Math.min(reach, 20)

  return [
    `M${source.x},${source.y}`,
    `C${source.x + reach},${source.y} ${source.x + reach},${midY} ${midX},${midY}`,
    `C${target.x - approach * 2},${midY} ${target.x - approach},${target.y} ${target.x},${target.y}`,
  ].join(' ')
}
