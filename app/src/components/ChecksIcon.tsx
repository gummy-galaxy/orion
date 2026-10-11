import type { ReactNode } from 'react'
import type { PullReadiness } from '../model'

const LINE = { fill: 'none', stroke: 'currentColor', strokeWidth: 1.6, strokeLinecap: 'round', strokeLinejoin: 'round' } as const
const DOTS = [1.6, 5, 8.4]

// Each state gets its own shape, so the result never rests on color alone.
const SHAPES: Record<PullReadiness, ReactNode> = {
  conflict: (
    <>
      <path d="M5 1.6v4.2" {...LINE} />
      <circle cx="5" cy="8.2" r="1.1" fill="currentColor" />
    </>
  ),
  failing: <path d="M2.7 2.7l4.6 4.6M7.3 2.7 2.7 7.3" {...LINE} />,
  running: (
    <g fill="currentColor">
      {DOTS.map((x) => (
        <circle key={x} cx={x} cy="5" r="1.1" />
      ))}
    </g>
  ),
  waiting: (
    <g fill="none" stroke="currentColor" strokeWidth="0.8">
      {DOTS.map((x) => (
        <circle key={x} cx={x} cy="5" r="0.9" />
      ))}
    </g>
  ),
  passing: <path d="M2 5.3 4.2 7.4 8 3" {...LINE} />,
  mergeable: (
    <path
      d="M.5 5a4.5 4.5 0 1 0 9 0a4.5 4.5 0 1 0-9 0ZM2.44 5.56 4.3 7.42 7.56 4.16 6.64 3.24 4.3 5.58 3.36 4.64Z"
      fill="currentColor"
      fillRule="evenodd"
    />
  ),
}

/** How close a pull request is to merging: a conflict, failing, running or queued checks, passing, or ready. */
export function ChecksIcon({ readiness, title }: { readiness: PullReadiness; title?: string }) {
  return (
    <svg
      viewBox="0 0 10 10"
      width="9"
      height="9"
      role={title ? 'img' : undefined}
      aria-hidden={title ? undefined : true}
      className={`checks-icon check-${readiness}`}
    >
      {title && <title>{title}</title>}
      {SHAPES[readiness]}
    </svg>
  )
}
