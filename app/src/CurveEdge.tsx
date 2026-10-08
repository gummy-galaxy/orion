import { BaseEdge, type EdgeProps } from '@xyflow/react'

/** Route arrows behind their source around the cards while keeping nearby arrows gently curved. */
export function CurveEdge(props: EdgeProps) {
  const { sourceX, sourceY, targetX, targetY, markerEnd, style, label, labelStyle } = props
  const reach = Math.min(80, Math.max(36, Math.abs(targetY - sourceY) / 3))

  // A target only slightly behind still reads fine as a gentle S.
  if (targetX >= sourceX - 24) {
    const bend = Math.max(Math.abs(targetX - sourceX) / 2, reach)
    const path = `M${sourceX},${sourceY} C${sourceX + bend},${sourceY} ${targetX - bend},${targetY} ${targetX},${targetY}`
    return (
      <BaseEdge
        path={path}
        markerEnd={markerEnd}
        style={style}
        label={label}
        labelStyle={labelStyle}
        labelX={(sourceX + targetX) / 2}
        labelY={(sourceY + targetY) / 2}
      />
    )
  }

  // Pass below cards in the same row; keep the approach inside the gap between neighbors.
  const midY = Math.abs(targetY - sourceY) < 60 ? Math.max(sourceY, targetY) + 60 : (sourceY + targetY) / 2
  const midX = (sourceX + targetX) / 2
  const approach = Math.min(reach, 20)
  const path = [
    `M${sourceX},${sourceY}`,
    `C${sourceX + reach},${sourceY} ${sourceX + reach},${midY} ${midX},${midY}`,
    `C${targetX - approach * 2},${midY} ${targetX - approach},${targetY} ${targetX},${targetY}`,
  ].join(' ')
  return <BaseEdge path={path} markerEnd={markerEnd} style={style} label={label} labelStyle={labelStyle} labelX={midX} labelY={midY} />
}
