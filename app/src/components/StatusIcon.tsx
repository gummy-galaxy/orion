import type { ReactNode } from 'react'
import type { ViewStatus } from '../model'

const RING = <circle cx="5" cy="5" r="3.9" fill="none" stroke="currentColor" strokeWidth="1.3" />

// Moving work fills the ring: empty when ready, half in progress, three quarters in review, solid when done.
const SHAPES: Record<ViewStatus, ReactNode> = {
  ready: RING,
  active: (
    <>
      {RING}
      <path d="M5 5V2.6A2.4 2.4 0 0 1 5 7.4Z" fill="currentColor" />
    </>
  ),
  review: (
    <>
      {RING}
      <path d="M5 5V2.6A2.4 2.4 0 1 1 2.6 5Z" fill="currentColor" />
    </>
  ),
  done: (
    <path
      d="M.5 5a4.5 4.5 0 1 0 9 0a4.5 4.5 0 1 0-9 0ZM2.44 5.56 4.3 7.42 7.56 4.16 6.64 3.24 4.3 5.58 3.36 4.64Z"
      fill="currentColor"
      fillRule="evenodd"
    />
  ),
  deferred: <circle cx="5" cy="5" r="3.9" fill="none" stroke="currentColor" strokeWidth="1.3" strokeDasharray="1.6 1.46" />,
  blocked: (
    <>
      <path d="M3.1 4.6V3.4a1.9 1.9 0 0 1 3.8 0v1.2" fill="none" stroke="currentColor" strokeWidth="1.3" />
      <rect x="1.6" y="4.6" width="6.8" height="4.9" rx="1.1" fill="currentColor" />
    </>
  ),
}

// Not the st-* classes, which also carry card effects such as the in-progress pulse.
const COLOR: Record<ViewStatus, string> = {
  ready: 'var(--status-ready)',
  active: 'var(--status-active)',
  review: 'var(--status-review)',
  blocked: 'var(--status-blocked)',
  deferred: 'var(--status-todo)',
  done: 'var(--status-done)',
}

/** A shape for each status, so telling them apart never rests on color alone. */
export function StatusIcon({ status }: { status: ViewStatus }) {
  return (
    <svg viewBox="0 0 10 10" width="10" height="10" aria-hidden="true" className="status-icon" style={{ color: COLOR[status] }}>
      {SHAPES[status]}
    </svg>
  )
}
