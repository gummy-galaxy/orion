import { useContext, useState } from 'react'
import { useInternalNode, useReactFlow } from '@xyflow/react'
import type { TaskNode } from '../model'
import { PLUG } from '../routing/routePlugs'
import type { Plug } from '../routing/types'
import { PlugContext } from './PlugContext'

/** Pins along the edge that meets the stub, so the plug reads as something that plugs in. */
const PINS = 'repeating-linear-gradient(to bottom, var(--edge-still) 0 2px, transparent 2px 4px)'

/**
 * A small copy of the card at the far end of a link. Hovering draws the link in full and shows which card it is, and
 * clicking jumps to that card, where a matching plug leads back.
 */
export function PlugChip({ plug }: { plug: Plug }) {
  const { reveal, flash } = useContext(PlugContext)
  const { getNode, setCenter, getZoom } = useReactFlow()
  const far = useInternalNode<TaskNode>(plug.card)
  const [hovered, setHovered] = useState(false)

  if (!far) return null

  const { label, status } = far.data
  const group = far.parentId ? (getNode(far.parentId)?.data as { label?: string } | undefined)?.label : undefined
  const pinsOnLeft = plug.side === 'out'

  const jump = () => {
    const { x, y } = far.internals.positionAbsolute

    reveal(null)
    setHovered(false)
    flash(plug.card)
    void setCenter(x + (far.measured.width ?? 0) / 2, y + (far.measured.height ?? 0) / 2, { zoom: Math.max(getZoom(), 0.8), duration: 500 })
  }

  return (
    <div
      className="nodrag nopan"
      data-plug={plug.side}
      data-owner={plug.owner}
      data-far={plug.card}
      data-more={plug.more}
      onMouseEnter={() => {
        setHovered(true)
        reveal(plug)
      }}
      onMouseLeave={() => {
        setHovered(false)
        reveal(null)
      }}
      onClick={jump}
      style={{
        position: 'absolute',
        transform: `translate(${plug.at.x}px, ${plug.at.y}px)`,
        width: PLUG.width,
        height: PLUG.height,
        pointerEvents: 'all',
        cursor: 'pointer',
        zIndex: hovered ? 2000 : 1000,
      }}
    >
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 2,
          height: '100%',
          boxSizing: 'border-box',
          flexDirection: pinsOnLeft ? 'row' : 'row-reverse',
          borderRadius: 3,
          border: `1px solid ${hovered ? 'var(--accent-default)' : 'var(--border-default)'}`,
          background: `color-mix(in srgb, var(--status-${status}) 22%, var(--surface-background))`,
          color: 'var(--text-primary)',
          font: '600 6px/1 system-ui, sans-serif',
          overflow: 'hidden',
        }}
      >
        <span style={{ alignSelf: 'stretch', width: 2, background: PINS, flex: 'none' }} />
        <span style={{ width: 4, height: 4, borderRadius: 2, background: `var(--status-${status})`, flex: 'none' }} />
        <span style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'clip', flex: 1 }}>{plug.more ? `+${plug.more + 1}` : label}</span>
      </div>
      {hovered ? (
        <div
          style={{
            position: 'absolute',
            bottom: PLUG.height + 6,
            [pinsOnLeft ? 'left' : 'right']: 0,
            width: 180,
            padding: '6px 8px',
            borderRadius: 8,
            background: 'var(--surface-background)',
            color: 'var(--text-primary)',
            border: '1px solid var(--accent-default)',
            boxShadow: 'var(--shadow-dialog)',
            font: '11px/1.35 system-ui, sans-serif',
            pointerEvents: 'none',
          }}
        >
          <div style={{ opacity: 0.7 }}>{plug.side === 'out' ? 'Blocks' : 'Blocked by'}</div>
          <div style={{ fontWeight: 600 }}>{label}</div>
          {group ? <div style={{ opacity: 0.7 }}>in {group}</div> : null}
          {plug.more ? <div style={{ opacity: 0.7 }}>and {plug.more} more far links</div> : null}
          <div style={{ marginTop: 4, opacity: 0.7 }}>Click to jump there</div>
        </div>
      ) : null}
    </div>
  )
}
