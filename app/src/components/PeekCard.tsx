import type { ReactNode } from 'react'

/** A card opened by inspect mode: full size or larger, nothing cut short, and its note below. */
export function PeekCard({ className, note, children }: { className: string; note?: string; children: ReactNode }) {
  return (
    <div className="pop-place peek-place">
      <div className={`${className} far-card peek-card`}>
        {children}
        {note && <p className="peek-note">{note}</p>}
      </div>
    </div>
  )
}
