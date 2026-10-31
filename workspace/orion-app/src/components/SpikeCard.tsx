import { memo } from 'react'
import { AREA_LABELS, AREA_TINTS } from '../selectionSpike/board'
import type { Area } from '../selectionSpike/types'

/** What a gesture would do to this card if it ended now. */
export type CardMark = 'none' | 'in-reach' | 'will-add' | 'will-remove' | 'will-move'

type Props = {
  id: string
  title: string
  area: Area
  x: number
  y: number
  selected: boolean
  mark: CardMark
  origin: boolean
  /** Shown on a card that a gather picked up, so it can be left behind. */
  leaveBehind?: (id: string) => void
  onFocusCard: (id: string) => void
}

/** A plain stand-in for a trading card: the same size, a title, and its area's tint. */
export const SpikeCard = memo(function SpikeCard({ id, title, area, x, y, selected, mark, origin, leaveBehind, onFocusCard }: Props) {
  const className = ['spike-card', selected && 'is-selected', mark !== 'none' && mark, origin && 'is-origin', area === 'new' && 'is-new']
    .filter(Boolean)
    .join(' ')

  return (
    <div
      className={className}
      data-card={id}
      role="button"
      tabIndex={0}
      aria-pressed={selected}
      aria-label={title}
      style={{ transform: `translate(${x}px, ${y}px)`, '--spike-tint': AREA_TINTS[area] } as React.CSSProperties}
      onFocus={() => onFocusCard(id)}
    >
      <div className="spike-card-art" />
      <div className="spike-card-title">{title}</div>
      <div className="spike-card-area">{AREA_LABELS[area]}</div>
      {leaveBehind && (
        <button
          type="button"
          className="spike-leave"
          title="Leave behind"
          aria-label={`Leave ${title} behind`}
          onPointerDown={(event) => event.stopPropagation()}
          onClick={(event) => {
            event.stopPropagation()
            leaveBehind(id)
          }}
        >
          ✕
        </button>
      )}
    </div>
  )
})
