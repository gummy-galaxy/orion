import type { SessionState } from '../sessions/types'

/** A session's state as a mark: a spinning arc while it works, a raised hand while it waits on you, a check once done. */
export function SessionStateIcon({ state }: { state: SessionState }) {
  return (
    <svg className={`session-state-icon session-state-icon-${state}`} viewBox="0 0 16 16" aria-hidden="true">
      {state === 'working' && <path d="M8 2a6 6 0 1 1-6 6" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" />}
      {state === 'waiting' && (
        <>
          <circle cx="8" cy="8" r="6.5" fill="currentColor" />
          <path d="M8 4.4v4.4" stroke="var(--session-icon-ink)" strokeWidth="2" strokeLinecap="round" />
          <circle cx="8" cy="11.4" r="1.1" fill="var(--session-icon-ink)" />
        </>
      )}
      {state === 'done' && (
        <>
          <circle cx="8" cy="8" r="6.5" fill="currentColor" />
          <path
            d="M5 8.2 7.1 10.3 11 6"
            fill="none"
            stroke="var(--session-icon-ink)"
            strokeWidth="1.9"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </>
      )}
    </svg>
  )
}
