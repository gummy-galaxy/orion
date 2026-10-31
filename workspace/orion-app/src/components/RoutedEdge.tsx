import { memo } from 'react'
import { BaseEdge, type Edge, type EdgeProps } from '@xyflow/react'
import type { Point } from '../routing/types'

export type RoutedEdgeData = { d: string; labelAt?: Point }

/** An edge that draws a path a router already worked out, ignoring where React Flow thinks its handles are. */
export const RoutedEdge = memo(function RoutedEdge({
  data,
  markerEnd,
  style,
  label,
  labelStyle,
  labelBgPadding,
  labelBgBorderRadius,
}: EdgeProps<Edge<RoutedEdgeData>>) {
  return (
    <BaseEdge
      path={data!.d}
      markerEnd={markerEnd}
      style={style}
      label={label}
      labelX={data!.labelAt?.x}
      labelY={data!.labelAt?.y}
      labelStyle={labelStyle}
      labelBgPadding={labelBgPadding}
      labelBgBorderRadius={labelBgBorderRadius}
    />
  )
})
