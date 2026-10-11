import type { ReactNode } from 'react'
import type { Motion, Sticker } from '../skins/slotFacts'

const PATHS: Record<Sticker | Motion, ReactNode> = {
  conflict: <path d="M4 2v12M12 2v5M12 7c0 4-8 3-8 7" />,
  failing: <path d="M4 4l8 8M12 4l-8 8" />,
  changes: (
    <>
      <path d="M2.5 3h11v7.5h-6L4.5 13.5v-3h-2z" />
      <path d="M8 5v2.6M8 9.2v.1" />
    </>
  ),
  stale: <path d="M4 2h8L8 8zM4 14h8L8 8z" />,
  mergeable: (
    <>
      <circle cx="4" cy="3.5" r="1.6" />
      <circle cx="12" cy="12.5" r="1.6" />
      <path d="M4 5v4a3.5 3.5 0 0 0 3.5 3.5H10" />
    </>
  ),
  running: <path d="M8 2a6 6 0 1 1-6 6" />,
  queued: (
    <>
      <circle cx="8" cy="8" r="6" />
      <path d="M8 4.5V8l2.5 1.5" />
    </>
  ),
}

export function SlotSignalIcon({ signal }: { signal: Sticker | Motion }) {
  return (
    <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      {PATHS[signal]}
    </svg>
  )
}
