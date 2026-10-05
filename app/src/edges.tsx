import { BaseEdge, getBezierPath, type EdgeProps } from '@xyflow/react'

/**
 * React Flow's curve, except where the target sits behind the source. There it squeezes into a tight S, so the arrow
 * instead leaves forward, turns through a point halfway between the two, and comes back into the target from behind.
 */
export function CurveEdge(props: EdgeProps) {
  const { sourceX: sx, sourceY: sy, targetX: tx, targetY: ty, sourcePosition, targetPosition, markerEnd, style, label, labelStyle } = props
  const reach = Math.min(80, Math.max(36, Math.abs(ty - sy) / 3))
  if (tx >= sx + reach) {
    const [path, labelX, labelY] = getBezierPath({ sourceX: sx, sourceY: sy, targetX: tx, targetY: ty, sourcePosition, targetPosition })
    return <BaseEdge path={path} markerEnd={markerEnd} style={style} label={label} labelStyle={labelStyle} labelX={labelX} labelY={labelY} />
  }
  // Cards in the same row would put the turn through them, so it passes below instead.
  const midY = Math.abs(ty - sy) < 60 ? Math.max(sy, ty) + 60 : (sy + ty) / 2
  const midX = (sx + tx) / 2
  // The way in stays inside the narrowest gap between neighboring cards so it doesn't run under the one beside it.
  const approach = Math.min(reach, 20)
  const path = [
    `M${sx},${sy}`,
    `C${sx + reach},${sy} ${sx + reach},${midY} ${midX},${midY}`,
    `C${tx - approach * 2},${midY} ${tx - approach},${ty} ${tx},${ty}`,
  ].join(' ')
  return <BaseEdge path={path} markerEnd={markerEnd} style={style} label={label} labelStyle={labelStyle} labelX={midX} labelY={midY} />
}
