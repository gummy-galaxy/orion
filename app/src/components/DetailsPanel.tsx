import type { ReactNode } from 'react'

/**
 * A fixed column on the right for the details of whatever is selected, so they never float over the canvas or come and
 * go with each click.
 */
export function DetailsPanel({ width, hide, children }: { width?: number; hide: () => void; children: ReactNode }) {
  return (
    <aside className="details" aria-label="Details" style={width ? { width } : undefined}>
      <div className="details-head" data-tauri-drag-region="deep">
        <span className="details-title">Details</span>
        <button type="button" className="side-hide" onClick={hide} title="Hide the details panel">
          ›
        </button>
      </div>
      <div className="details-body">{children}</div>
    </aside>
  )
}
