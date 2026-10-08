import { useEffect, useRef, useState, type SyntheticEvent } from 'react'
import type { SourceRef } from '../derive'
import { Favicon } from './Favicon'
import { SourceLink } from './SourceLink'

const stopPropagation = (event: SyntheticEvent) => event.stopPropagation()

export function SourceMenu({ domain, sources }: { domain: string; sources: SourceRef[] }) {
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDetailsElement>(null)

  useEffect(() => {
    if (!open) return
    const dismiss = (event: PointerEvent) => {
      if (!ref.current?.contains(event.target as Node)) setOpen(false)
    }
    document.addEventListener('pointerdown', dismiss, true)
    return () => document.removeEventListener('pointerdown', dismiss, true)
  }, [open])

  return (
    <details
      ref={ref}
      open={open}
      className="source-domain source-domain-many nodrag"
      onToggle={(event) => setOpen(event.currentTarget.open)}
      onPointerDown={stopPropagation}
      onClick={stopPropagation}
    >
      <summary aria-label={`${domain}: ${sources.length} sources`} title={`${domain}: ${sources.length} sources. Click to show them.`}>
        <Favicon domain={domain} />
        <span className="source-count">{sources.length}</span>
      </summary>
      <div className="source-menu">
        <strong>{domain}</strong>
        <ul>
          {sources.map((source) => (
            <li key={source.label}>
              <SourceLink source={source}>{source.label}</SourceLink>
            </li>
          ))}
        </ul>
      </div>
    </details>
  )
}
