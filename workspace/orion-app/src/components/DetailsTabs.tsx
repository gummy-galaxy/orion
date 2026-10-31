import type { KeyboardEvent } from 'react'
import { DETAILS_TABS, type DetailsTab } from '../detailsTabs'

const STEP: Record<string, number> = { ArrowLeft: -1, ArrowRight: 1 }

/** The details panel's tabs. The arrow keys move between them, as in any tab list. */
export function DetailsTabs({ tab, choose }: { tab: DetailsTab; choose: (tab: DetailsTab) => void }) {
  const move = (event: KeyboardEvent<HTMLDivElement>) => {
    const step = STEP[event.key]

    if (!step) return

    event.preventDefault()
    const index = DETAILS_TABS.findIndex((entry) => entry.id === tab)
    const next = DETAILS_TABS[(index + step + DETAILS_TABS.length) % DETAILS_TABS.length].id

    choose(next)
    document.getElementById(`details-tab-${next}`)?.focus()
  }

  return (
    <div className="details-tabs" role="tablist" aria-label="Details panel" onKeyDown={move}>
      {DETAILS_TABS.map((entry) => (
        <button
          type="button"
          role="tab"
          key={entry.id}
          id={`details-tab-${entry.id}`}
          className="details-tab"
          aria-selected={entry.id === tab}
          aria-controls="details-tabpanel"
          tabIndex={entry.id === tab ? 0 : -1}
          onClick={() => choose(entry.id)}
        >
          {entry.label}
        </button>
      ))}
    </div>
  )
}
