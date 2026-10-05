import { BaseEdge, type Edge, type EdgeProps } from '@xyflow/react'

/** How far each end sits from its handle, so arrows spread across a card's side instead of meeting at one point. */
export type CurveData = { sourceShift?: number; targetShift?: number }

/**
 * A curve that always swings out far enough to read. Where the target sits well behind the source a curve squeezes
 * into a tight S, so the arrow instead leaves forward, turns through a point halfway between the two, and comes back
 * into the target from behind.
 */
export function CurveEdge(props: EdgeProps<Edge<CurveData>>) {
  const { sourceX: sx, targetX: tx, data, markerEnd, style, label, labelStyle } = props
  const sy = props.sourceY + (data?.sourceShift ?? 0)
  const ty = props.targetY + (data?.targetShift ?? 0)
  const reach = Math.min(80, Math.max(36, Math.abs(ty - sy) / 3))
  // A target only slightly behind still reads fine as a gentle S; the loop is for ones well behind.
  if (tx >= sx - 24) {
    // Cards close together sideways but far apart vertically would otherwise drop almost straight down.
    const out = Math.max(Math.abs(tx - sx) / 2, reach)
    const path = `M${sx},${sy} C${sx + out},${sy} ${tx - out},${ty} ${tx},${ty}`
    return (
      <BaseEdge path={path} markerEnd={markerEnd} style={style} label={label} labelStyle={labelStyle} labelX={(sx + tx) / 2} labelY={(sy + ty) / 2} />
    )
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
