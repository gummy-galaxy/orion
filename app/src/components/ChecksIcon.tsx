import type { PullDetails } from '../model'

type Checks = NonNullable<PullDetails['checks']>

const LINE = { fill: 'none', stroke: 'currentColor', strokeWidth: 1.6, strokeLinecap: 'round', strokeLinejoin: 'round' } as const

/** A pull request's checks as a check, a cross, or dots while they run, so the result never rests on color alone. */
export function ChecksIcon({ checks, title }: { checks: Checks; title?: string }) {
  const failed = checks === 'FAILURE' || checks === 'ERROR'

  return (
    <svg
      viewBox="0 0 10 10"
      width="9"
      height="9"
      role={title ? 'img' : undefined}
      aria-hidden={title ? undefined : true}
      className={`checks-icon check-${checks.toLowerCase()}`}
    >
      {title && <title>{title}</title>}
      {checks === 'SUCCESS' ? (
        <path d="M2 5.3 4.2 7.4 8 3" {...LINE} />
      ) : failed ? (
        <path d="M2.7 2.7l4.6 4.6M7.3 2.7 2.7 7.3" {...LINE} />
      ) : (
        <g fill="currentColor">
          <circle cx="1.6" cy="5" r="1.1" />
          <circle cx="5" cy="5" r="1.1" />
          <circle cx="8.4" cy="5" r="1.1" />
        </g>
      )}
    </svg>
  )
}
