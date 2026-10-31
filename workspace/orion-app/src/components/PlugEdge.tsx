import { memo } from 'react'
import { BaseEdge, EdgeLabelRenderer, type Edge, type EdgeProps } from '@xyflow/react'
import { PLUG } from '../routing/routePlugs'
import type { Plug } from '../routing/types'
import { PlugChip } from './PlugChip'

export type PlugEdgeData = { d: string; plug: Plug }

/** A stub that fades from its card toward a plug standing in for the card at the other end. */
export const PlugEdge = memo(function PlugEdge({ id, data, markerEnd }: EdgeProps<Edge<PlugEdgeData>>) {
  const { d, plug } = data!
  const attach = { x: plug.side === 'out' ? plug.at.x : plug.at.x + PLUG.width, y: plug.at.y + PLUG.height / 2 }
  const gradient = `fade-${id}`

  return (
    <>
      <defs>
        <linearGradient id={gradient} gradientUnits="userSpaceOnUse" x1={plug.port.x} y1={plug.port.y} x2={attach.x} y2={attach.y}>
          <stop offset="0" style={{ stopColor: 'var(--edge-still)', stopOpacity: 1 }} />
          <stop offset="1" style={{ stopColor: 'var(--edge-still)', stopOpacity: 0.2 }} />
        </linearGradient>
      </defs>
      <BaseEdge path={d} markerEnd={markerEnd} style={{ stroke: `url(#${gradient})` }} />
      <EdgeLabelRenderer>
        <PlugChip plug={plug} />
      </EdgeLabelRenderer>
    </>
  )
})
