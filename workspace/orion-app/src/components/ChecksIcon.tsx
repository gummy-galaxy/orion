import type { ReactNode } from 'react'
import type { PullReadiness } from '../model'
import { MergeIcon } from './MergeIcon'

const DOT = <circle cx="5" cy="5" r="4" fill="currentColor" />
const RING = { fill: 'none', stroke: 'currentColor', strokeWidth: 1.4 } as const

// Dots, with just enough shape that no state rests on color alone: a ring while queued, and a ring around a dot for
// a conflict. Ready to merge is its own kind of state and draws the merge glyph instead.
const SHAPES: Record<Exclude<PullReadiness, 'mergeable'>, ReactNode> = {
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
}

/**
 * How close a pull request is to merging: a conflict, failing, running or queued checks, passing, or ready.
 * `badge` adds a cutout of the card's fill around it, to sit on the corner of the status icon.
 */
export function ChecksIcon({
  readiness,
  title,
  badge = false,
}: {
  readiness: PullReadiness
  title?: string
  badge?: boolean
}) {
  if (readiness === 'mergeable') return <MergeIcon title={title} className="checks-icon check-mergeable" />

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
