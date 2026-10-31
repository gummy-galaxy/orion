import type { ReactNode } from 'react'
import type { Who } from '../model'

const LABEL: Record<Who, string> = { you: 'Your move', review: 'Waiting on review', ci: 'Waiting on CI' }

// Drawn in the surface color over the badge, so the glyph tells whose move it is without its color.
const GLYPHS: Record<Who, ReactNode> = {
  you: (
    <>
      <circle cx="7.5" cy="5.6" r="1.9" />
      <path d="M4.3 11a3.2 3.2 0 0 1 6.4 0Z" />
    </>
  ),
  review: (
    <>
      <path d="M3 7.5C4.2 5.4 5.7 4.4 7.5 4.4s3.3 1 4.5 3.1c-1.2 2.1-2.7 3.1-4.5 3.1S4.2 9.6 3 7.5Z" />
      <circle cx="7.5" cy="7.5" r="1.3" className="who-pupil" />
    </>
  ),
  ci: (
    <>
      <circle
        cx="7.5"
        cy="7.5"
        r="3.6"
        fill="none"
        stroke="var(--surface-background)"
        strokeWidth="1.6"
        strokeDasharray="1.3 1.53"
      />
      <circle cx="7.5" cy="7.5" r="2.2" fill="none" stroke="var(--surface-background)" strokeWidth="1.4" />
    </>
  ),
}

/** Whose move a card waits on, as a person, an eye, or a gear on a colored badge. */
export function WhoBadge({ who }: { who: Who }) {
  return (
    <svg viewBox="0 0 15 15" width="15" height="15" role="img" className={`who who-${who}`}>
      <title>{LABEL[who]}</title>
      <circle cx="7.5" cy="7.5" r="6.5" className="who-disc" />
      <g fill="var(--surface-background)">{GLYPHS[who]}</g>
    </svg>
  )
}
