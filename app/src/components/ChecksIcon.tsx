import type { ReactNode } from 'react'
import type { PullReadiness } from '../model'

const DOT = <circle cx="5" cy="5" r="4" fill="currentColor" />
const RING = { fill: 'none', stroke: 'currentColor', strokeWidth: 1.4 } as const

// Dots, with just enough shape that no state rests on color alone: a ring while queued, a ring around a dot for a
// conflict, and a halo once the pull request is ready to merge.
const SHAPES: Record<PullReadiness, ReactNode> = {
  conflict: (
    <>
      <circle cx="5" cy="5" r="3.9" {...RING} />
      <circle cx="5" cy="5" r="1.7" fill="currentColor" />
    </>
  ),
  failing: DOT,
  running: DOT,
  waiting: <circle cx="5" cy="5" r="3.6" {...RING} />,
  passing: DOT,
  mergeable: (
    <>
      <circle cx="5" cy="5" r="4.4" fill="currentColor" opacity="0.35" />
      <circle cx="5" cy="5" r="3.2" fill="currentColor" />
    </>
  ),
}

/**
 * How close a pull request is to merging: a conflict, failing, running or queued checks, passing, or ready.
 * `badge` adds a cutout of the card's fill around it, to sit on the corner of the status icon.
 */
export function ChecksIcon({ readiness, title, badge = false }: { readiness: PullReadiness; title?: string; badge?: boolean }) {
  return (
    <svg
      viewBox={badge ? '-2 -2 14 14' : '0 0 10 10'}
      width={badge ? 9 : 8}
      height={badge ? 9 : 8}
      role={title ? 'img' : undefined}
      aria-hidden={title ? undefined : true}
      className={`checks-icon check-${readiness}`}
    >
      {title && <title>{title}</title>}
      {badge && <circle className="checks-knockout" cx="5" cy="5" r="7" />}
      {SHAPES[readiness]}
    </svg>
  )
}
