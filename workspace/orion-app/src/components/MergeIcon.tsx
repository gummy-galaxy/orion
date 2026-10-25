/** A merge: two commits joining a third. Marks a pull request that is ready to merge, and the button that merges it. */
export function MergeIcon({ size = 10, title, className }: { size?: number; title?: string; className?: string }) {
  return (
    <svg viewBox="0 0 16 16" width={size} height={size} role={title ? 'img' : undefined} aria-hidden={title ? undefined : true} className={className}>
      {title && <title>{title}</title>}
      <path d="M4.5 3.5v9M4.5 5.5c0 2.5 2.5 3.5 7 3.5" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      <g fill="currentColor">
        <circle cx="4.5" cy="3.2" r="2.2" />
        <circle cx="4.5" cy="12.8" r="2.2" />
        <circle cx="11.8" cy="9" r="2.2" />
      </g>
    </svg>
  )
}
