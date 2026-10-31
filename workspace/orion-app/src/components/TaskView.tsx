import { TASK_HEIGHT, TASK_WIDTH } from '../geometry'
import { memo, useContext, useState, useSyncExternalStore, type CSSProperties } from 'react'
import { Handle, Position, useStore, type NodeProps } from '@xyflow/react'
import { type TaskNode } from '../model'
import { useAtomValue } from 'jotai'
import { ActionsContext } from '../derive'
import {
  useCardView,
  useCelebrating,
  useChainFinale,
  useMarked,
  useSnoozed,
  useTint,
  useTraceRole,
  inspectingAtom,
  skinAtom,
  skinStore,
} from '../state'
import { CardBody } from './CardBody'
import { ComponentCard } from './ComponentCard'
import { FarTag } from './FarTag'
import { PeekCard } from './PeekCard'
import { getCompactZoom, subscribeCompactZoom } from '../zoomLevel'

/** Where a card's title is, across the three skins and notes. */
const TITLE_SELECTOR = '.label, .plain-title, .trading-title, .note-text, .plain-note-text, .trading-note-text'

/** The middle of the card's title text, as a percentage of the card, so a hover lift grows out of the title. */
function liftOrigin(card: HTMLElement) {
  const title = card.querySelector<HTMLElement>(TITLE_SELECTOR)
  const box = card.getBoundingClientRect()

  if (!title || !box.width || !box.height) return '50% 50%'

  // Text can be narrower than its block, so measure the words themselves.
  const range = document.createRange()

  range.selectNodeContents(title)

  const words = range.getBoundingClientRect()
  const text = words.width ? words : title.getBoundingClientRect()
  const x = ((text.left + text.width / 2 - box.left) / box.width) * 100
  const y = ((text.top + text.height / 2 - box.top) / box.height) * 100

  return `${x}% ${y}%`
}

// Memoized because React Flow re-renders every node wrapper whenever the canvas passes new handlers.
export const TaskView = memo(function TaskView({ id, data, parentId, selected, width, height }: NodeProps<TaskNode>) {
  const [hovered, setHovered] = useState(false)
  // Only a hovered or selected card reads the zoom, so zooming across the breakpoint doesn't re-render every card. The
  // compact look for all cards is CSS keyed off the canvas's data-zoom. Retuning the breakpoint in the debug bar
  // re-renders cards, so a selected card's tag follows the new value at once.
  const breakpoint = useSyncExternalStore(subscribeCompactZoom, getCompactZoom)
  const far = useStore((state) => (hovered || selected) && state.transform[2] < breakpoint)
  // Inspect mode opens the hovered card in full.
  const peeking = useAtomValue(inspectingAtom) && hovered
  const view = useCardView(id, data, parentId)
  const trace = useTraceRole(id)
  const attention = useMarked(id)
  const snoozedUntil = useSnoozed(id)
  const actions = useContext(ActionsContext)!
  const tint = useTint(id)
  // A card keeps its badge while the badge clears, after the flag itself is already gone.
  const clearing = useCelebrating(id)
  const finished = view.kind !== 'note' && view.kind !== 'component' && view.status === 'done'
  // Finished work shimmers until someone closes it out, then carries a Done stamp from then on.
  const waiting = finished && !!data.celebrate && clearing === undefined
  const badged = waiting || clearing !== undefined
  // The last beat of a chain closing out rings out from its card, so the chain ends on something.
  const finaleDelay = useChainFinale(id)
  const finale = finaleDelay !== undefined && clearing !== undefined
  const skin = useAtomValue(skinAtom, { store: skinStore })
  const className =
    view.kind === 'note'
      ? `card skin-${skin} note${trace ? ' tr-' + trace : ''}`
      : view.kind === 'component'
        ? `card component shape-${data.shape ?? 'service'}${tint ? ' tint-' + tint : ''}${trace ? ' tr-' + trace : ''}`
        : `card skin-${skin} st-${view.status}${view.kind === 'placeholder' ? ' placeholder' : ''}` +
          `${view.kind === 'gate' ? ' gate' : ''}${trace ? ' tr-' + trace : ''}${attention ? ' attn' : ''}` +
          `${view.readyToMerge ? ' ready-to-merge' : ''}${waiting ? ' is-waiting' : ''}` +
          `${snoozedUntil ? ' snoozed' : ''}`
  const body = (
    <>
      {view.kind === 'component' ? (
        <ComponentCard
          view={view}
          shape={data.shape ?? 'service'}
          width={width ?? TASK_WIDTH}
          height={height ?? TASK_HEIGHT}
        />
      ) : (
        <CardBody view={view} />
      )}
      {finished && !waiting && (
        <span
          className={`done-stamp${clearing !== undefined ? ' is-landing' : ''}`}
          style={clearing !== undefined ? ({ '--clear-delay': `${clearing}ms` } as CSSProperties) : undefined}
        >
          Done
        </span>
      )}
      {finale && (
        <span
          className="chain-flourish"
          style={{ '--clear-delay': `${finaleDelay}ms` } as CSSProperties}
          aria-hidden="true"
        />
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
            <path
              d="M2.3 5.2 4.2 7.1 7.8 3.2"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.7"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </button>
      )}
    </>
  )

  return (
    <div
      className={className}
      title={snoozedUntil ? `Snoozed until ${new Date(snoozedUntil).toLocaleString()}` : undefined}
      onPointerEnter={(event) => {
        event.currentTarget.style.transformOrigin = liftOrigin(event.currentTarget)
        setHovered(true)
      }}
      onPointerLeave={() => setHovered(false)}
    >
      <Handle type="target" position={Position.Left} />
      {/* Only one card at a time grows into a tag, so tags never pile over their neighbors. */}
      {peeking ? (
        <PeekCard
          className={className}
          note={view.kind === 'note' || view.kind === 'component' ? undefined : view.note}
        >
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
