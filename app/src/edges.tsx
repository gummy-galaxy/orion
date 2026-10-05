import { memo } from 'react'
import { BaseEdge, useStore, type EdgeProps } from '@xyflow/react'

/** Screen pixels past the edge of the canvas that still count as showing, so arrows start moving just before they arrive. */
const SCREEN_MARGIN = 24

type Box = { minX: number; minY: number; maxX: number; maxY: number }

function boxOf(xs: number[], ys: number[]): Box {
  return { minX: Math.min(...xs), minY: Math.min(...ys), maxX: Math.max(...xs), maxY: Math.max(...ys) }
}

/**
 * A curve that always swings out far enough to read. Where the target sits well behind the source a curve squeezes
 * into a tight S, so the arrow instead leaves forward, turns through a point halfway between the two, and comes back
 * into the target from behind.
 */
export const CurveEdge = memo(function CurveEdge(props: EdgeProps) {
  const { sourceX: sx, sourceY: sy, targetX: tx, targetY: ty, markerEnd, style, label, labelStyle } = props
  const reach = Math.min(80, Math.max(36, Math.abs(ty - sy) / 3))
  let path: string
  let labelX: number
  let labelY: number
  // Every point of a Bezier curve lies inside the box around its end and control points.
  let box: Box
  // A target only slightly behind still reads fine as a gentle S; the loop is for ones well behind.
  if (tx >= sx - 24) {
    // Cards close together sideways but far apart vertically would otherwise drop almost straight down.
    const out = Math.max(Math.abs(tx - sx) / 2, reach)
    path = `M${sx},${sy} C${sx + out},${sy} ${tx - out},${ty} ${tx},${ty}`
    labelX = (sx + tx) / 2
    labelY = (sy + ty) / 2
    box = boxOf([sx, sx + out, tx - out, tx], [sy, ty])
  } else {
    // Cards in the same row would put the turn through them, so it passes below instead.
    const midY = Math.abs(ty - sy) < 60 ? Math.max(sy, ty) + 60 : (sy + ty) / 2
    const midX = (sx + tx) / 2
    // The way in stays inside the narrowest gap between neighboring cards so it doesn't run under the one beside it.
    const approach = Math.min(reach, 20)
    path = [
      `M${sx},${sy}`,
      `C${sx + reach},${sy} ${sx + reach},${midY} ${midX},${midY}`,
      `C${tx - approach * 2},${midY} ${tx - approach},${ty} ${tx},${ty}`,
    ].join(' ')
    labelX = midX
    labelY = midY
    box = boxOf([sx, sx + reach, midX, tx - approach * 2, tx], [sy, midY, ty])
  }
  const shown = useStore(({ transform: [x, y, zoom], width, height }) => {
    return (
      box.maxX * zoom + x >= -SCREEN_MARGIN &&
      box.minX * zoom + x <= width + SCREEN_MARGIN &&
      box.maxY * zoom + y >= -SCREEN_MARGIN &&
      box.minY * zoom + y <= height + SCREEN_MARGIN
    )
  })
  return (
    <BaseEdge
      path={path}
      className={shown ? undefined : 'is-offscreen'}
      markerEnd={markerEnd}
      style={style}
      label={label}
      labelStyle={labelStyle}
      labelX={labelX}
      labelY={labelY}
    />
  )
})
