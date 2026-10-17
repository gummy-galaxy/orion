import { memo } from 'react'
import { BaseEdge, useStore, type EdgeProps } from '@xyflow/react'

/** Screen pixels past the canvas edge that still count as showing, so arrows start moving just before they arrive. */
const SCREEN_MARGIN = 24

type Box = { minX: number; minY: number; maxX: number; maxY: number }

function boxOf(xs: number[], ys: number[]): Box {
  return { minX: Math.min(...xs), minY: Math.min(...ys), maxX: Math.max(...xs), maxY: Math.max(...ys) }
}

/** Route arrows behind their source around the cards while keeping nearby arrows gently curved. */
export const CurveEdge = memo(function CurveEdge(props: EdgeProps) {
  const { sourceX, sourceY, targetX, targetY, markerEnd, style, label, labelStyle, labelBgPadding, labelBgBorderRadius } = props
  const reach = Math.min(80, Math.max(36, Math.abs(targetY - sourceY) / 3))
  let path: string
  let labelX: number
  let labelY: number
  // Every point of a Bézier curve lies inside the box around its end and control points.
  let box: Box

  // A target only slightly behind still reads fine as a gentle S.
  if (targetX >= sourceX - 24) {
    const bend = Math.max(Math.abs(targetX - sourceX) / 2, reach)

    path = `M${sourceX},${sourceY} C${sourceX + bend},${sourceY} ${targetX - bend},${targetY} ${targetX},${targetY}`
    labelX = (sourceX + targetX) / 2
    labelY = (sourceY + targetY) / 2
    box = boxOf([sourceX, sourceX + bend, targetX - bend, targetX], [sourceY, targetY])
  } else {
    // Pass below cards in the same row; keep the approach inside the gap between neighbors.
    const midY = Math.abs(targetY - sourceY) < 60 ? Math.max(sourceY, targetY) + 60 : (sourceY + targetY) / 2
    const midX = (sourceX + targetX) / 2
    const approach = Math.min(reach, 20)

    path = [
      `M${sourceX},${sourceY}`,
      `C${sourceX + reach},${sourceY} ${sourceX + reach},${midY} ${midX},${midY}`,
      `C${targetX - approach * 2},${midY} ${targetX - approach},${targetY} ${targetX},${targetY}`,
    ].join(' ')
    labelX = midX
    labelY = midY
    box = boxOf([sourceX, sourceX + reach, midX, targetX - approach * 2, targetX], [sourceY, midY, targetY])
  }

  // A boolean selector, so panning re-renders an arrow only when it crosses the edge of the canvas.
  const shown = useStore(
    ({ transform: [x, y, zoom], width, height }) =>
      box.maxX * zoom + x >= -SCREEN_MARGIN &&
      box.minX * zoom + x <= width + SCREEN_MARGIN &&
      box.maxY * zoom + y >= -SCREEN_MARGIN &&
      box.minY * zoom + y <= height + SCREEN_MARGIN,
  )

  return (
    <BaseEdge
      path={path}
      className={shown ? undefined : 'is-offscreen'}
      markerEnd={markerEnd}
      style={style}
      label={label}
      labelStyle={labelStyle}
      labelBgPadding={labelBgPadding}
      labelBgBorderRadius={labelBgBorderRadius}
      labelX={labelX}
      labelY={labelY}
    />
  )
})
