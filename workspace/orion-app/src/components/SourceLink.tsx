import type { ReactNode, SyntheticEvent } from 'react'
import type { SourceRef } from '../derive'

/** Keeps a click on a link from also selecting, dragging, or opening the node it sits on. */
const stopPropagation = (event: SyntheticEvent) => event.stopPropagation()

export function SourceLink({
  source,
  label,
  className,
  children,
}: {
  source: SourceRef
  label?: string
  className?: string
  children: ReactNode
}) {
  return source.href ? (
    <a
      className={className}
      href={source.href}
      target="_blank"
      rel="noreferrer"
      aria-label={label}
      onPointerDown={stopPropagation}
      onClick={stopPropagation}
      onDoubleClick={stopPropagation}
    >
      {children}
    </a>
  ) : (
    <span className={className} role={label ? 'img' : undefined} aria-label={label}>
      {children}
    </span>
  )
}
