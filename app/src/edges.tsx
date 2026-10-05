import { BaseEdge, getSmoothStepPath, type Edge, type EdgeProps } from '@xyflow/react'
import type { Route } from './layout'

export type RoutedEdge = Edge<{ route?: Route }, 'routed'>

const RADIUS = 8

/** A path through `points` that rounds each bend, never by more than half of either segment beside it. */
function roundedPath(points: Route, radius = RADIUS): string {
  if (points.length < 2) return ''
  let d = `M${points[0].x},${points[0].y}`
  for (let i = 1; i < points.length - 1; i++) {
    const [a, b, c] = [points[i - 1], points[i], points[i + 1]]
    const r = Math.min(radius, Math.hypot(b.x - a.x, b.y - a.y) / 2, Math.hypot(c.x - b.x, c.y - b.y) / 2)
    const toward = (p: { x: number; y: number }) => {
      const len = Math.hypot(p.x - b.x, p.y - b.y) || 1
      return { x: b.x + ((p.x - b.x) / len) * r, y: b.y + ((p.y - b.y) / len) * r }
    }
    const before = toward(a)
    const after = toward(c)
    d += ` L${before.x},${before.y} Q${b.x},${b.y} ${after.x},${after.y}`
  }
  const end = points[points.length - 1]
  return d + ` L${end.x},${end.y}`
}

/** Follows the route ELK found when it has one; otherwise runs at right angles like a `smoothstep` edge. */
export function RoutedEdgeView(props: EdgeProps<RoutedEdge>) {
  const { data, sourceX, sourceY, targetX, targetY, sourcePosition, targetPosition, markerEnd, style, label, labelStyle } = props
  const route = data?.route
  if (route && route.length > 1) {
    const mid = route[Math.floor((route.length - 1) / 2)]
    const next = route[Math.floor((route.length - 1) / 2) + 1]
    return (
      <BaseEdge
        path={roundedPath(route)}
        markerEnd={markerEnd}
        style={style}
        label={label}
        labelStyle={labelStyle}
        labelX={(mid.x + next.x) / 2}
        labelY={(mid.y + next.y) / 2}
      />
    )
  }
  const [path, labelX, labelY] = getSmoothStepPath({ sourceX, sourceY, targetX, targetY, sourcePosition, targetPosition, borderRadius: RADIUS })
  return <BaseEdge path={path} markerEnd={markerEnd} style={style} label={label} labelStyle={labelStyle} labelX={labelX} labelY={labelY} />
}
