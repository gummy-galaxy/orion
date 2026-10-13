import { memo, useContext, useState, useSyncExternalStore, type CSSProperties } from 'react'
import { Handle, Position, useStore, type NodeProps } from '@xyflow/react'
import type { TaskNode } from '../model'
import { useAtomValue } from 'jotai'
import { ActionsContext } from '../derive'
import { useCardView, useCelebrating, useMarked, useTraceRole, inspectingAtom, skinAtom, skinStore } from '../state'
import { CardBody } from './CardBody'
import { FarTag } from './FarTag'
import { PeekCard } from './PeekCard'
import { getCompactZoom, subscribeCompactZoom } from '../zoomLevel'

// Memoized because React Flow re-renders every node wrapper whenever the canvas passes new handlers.
export const TaskView = memo(function TaskView({ id, data, parentId, selected }: NodeProps<TaskNode>) {
  const [hovered, setHovered] = useState(false)
  // Only a hovered or selected card reads the zoom, so zooming across the breakpoint doesn't re-render every card. The
  // compact look for all cards is CSS keyed off the canvas's data-zoom. Retuning the breakpoint in the debug bar re-renders
  // cards, so a selected card's tag follows the new value at once.
  const breakpoint = useSyncExternalStore(subscribeCompactZoom, getCompactZoom)
  const far = useStore((state) => (hovered || selected) && state.transform[2] < breakpoint)
  // Inspect mode opens the hovered card in full.
  const peeking = useAtomValue(inspectingAtom) && hovered
  const view = useCardView(id, data, parentId)
  const trace = useTraceRole(id)
  const attention = useMarked(id)
  const actions = useContext(ActionsContext)!
  // A card keeps its badge while the badge clears, after the flag itself is already gone.
  const clearing = useCelebrating(id)
  const finished = view.kind !== 'note' && view.status === 'done'
  // Finished work shimmers until someone closes it out, then carries a Done stamp from then on.
  const waiting = finished && !!data.celebrate && clearing === undefined
  const badged = waiting || clearing !== undefined
  const skin = useAtomValue(skinAtom, { store: skinStore })
  const className =
    view.kind === 'note'
      ? `card skin-${skin} note${trace ? ' tr-' + trace : ''}`
      : `card skin-${skin} st-${view.status}${view.kind === 'placeholder' ? ' placeholder' : ''}${view.kind === 'gate' ? ' gate' : ''}${trace ? ' tr-' + trace : ''}${attention ? ' attn' : ''}${view.readyToMerge ? ' ready-to-merge' : ''}${waiting ? ' is-waiting' : ''}`
  const body = (
    <>
      <CardBody view={view} />
      {finished && !waiting && (
        <span
          className={`done-stamp${clearing !== undefined ? ' is-landing' : ''}`}
          style={clearing !== undefined ? ({ '--clear-delay': `${clearing}ms` } as CSSProperties) : undefined}
        >
          Done
        </span>
      )}
      {badged && (
        <button
          type="button"
          className={`finish-stamp nodrag nopan${clearing !== undefined ? ' is-clearing' : ''}`}
          style={clearing !== undefined ? ({ '--clear-delay': `${clearing}ms` } as CSSProperties) : undefined}
          aria-label={`Close out ${view.title}`}
          title="Click to close out"
          onClick={(event) => {
            event.stopPropagation()

            if (clearing === undefined) actions.celebrate(id)
          }}
        >
          <svg viewBox="0 0 10 10" aria-hidden="true">
            <path d="M2.3 5.2 4.2 7.1 7.8 3.2" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </button>
      )}
    </>
  )

  return (
    <div className={className} onPointerEnter={() => setHovered(true)} onPointerLeave={() => setHovered(false)}>
      <Handle type="target" position={Position.Left} />
      {/* Only one card at a time grows into a tag, so tags never pile over their neighbors. */}
      {peeking ? (
        <PeekCard className={className} note={view.kind === 'note' ? undefined : view.note}>
          {body}
        </PeekCard>
      ) : far ? (
        <FarTag className={className}>{body}</FarTag>
      ) : (
        body
      )}
      <Handle type="source" position={Position.Right} />
    </div>
  )
})
