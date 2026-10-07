import { BaseEdge, type EdgeProps } from '@xyflow/react'

/** Route arrows behind their source around the cards while keeping nearby arrows gently curved. */
export function CurveEdge(props: EdgeProps) {
  const { sourceX: sx, sourceY: sy, targetX: tx, targetY: ty, markerEnd, style, label, labelStyle } = props
  const reach = Math.min(80, Math.max(36, Math.abs(ty - sy) / 3))

  // A target only slightly behind still reads fine as a gentle S.
  if (tx >= sx - 24) {
    const out = Math.max(Math.abs(tx - sx) / 2, reach)
    const path = `M${sx},${sy} C${sx + out},${sy} ${tx - out},${ty} ${tx},${ty}`
    return (
      <BaseEdge path={path} markerEnd={markerEnd} style={style} label={label} labelStyle={labelStyle} labelX={(sx + tx) / 2} labelY={(sy + ty) / 2} />
    )
  }

  // Pass below cards in the same row; keep the approach inside the gap between neighbors.
  const midY = Math.abs(ty - sy) < 60 ? Math.max(sy, ty) + 60 : (sy + ty) / 2
  const midX = (sx + tx) / 2
  const approach = Math.min(reach, 20)
  const path = [
    `M${sx},${sy}`,
    `C${sx + reach},${sy} ${sx + reach},${midY} ${midX},${midY}`,
    `C${tx - approach * 2},${midY} ${tx - approach},${ty} ${tx},${ty}`,
  ].join(' ')
  return <BaseEdge path={path} markerEnd={markerEnd} style={style} label={label} labelStyle={labelStyle} labelX={midX} labelY={midY} />
}
