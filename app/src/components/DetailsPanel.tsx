import type { ReactNode } from 'react'

/**
 * A fixed column on the right for the details of whatever is selected, so they never float over the canvas or come and
 * go with each click. Spike #102: `title` swaps in tabs for the table view, and `wide` lets that view run edge to edge.
 */
export function DetailsPanel({
  width,
  wide = false,
  title = 'Details',
  hide,
  children,
}: {
  width?: number
  wide?: boolean
  title?: ReactNode
  hide: () => void
  children: ReactNode
}) {
  return (
    <aside className={wide ? 'details is-wide' : 'details'} aria-label="Details" style={width ? { width } : undefined}>
      <div className="details-head" data-tauri-drag-region="deep">
        <span className="details-title">{title}</span>
        <button type="button" className="side-hide" onClick={hide} title="Hide the details panel">
          ›
        </button>
      </div>
      <div className="details-body">{children}</div>
    </aside>
  )
}
