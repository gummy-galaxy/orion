import type { SourceRef } from '../derive'
import { Favicon } from './Favicon'
import { SourceLink } from './SourceLink'
import { SourceMenu } from './SourceMenu'

export function SourceBadges({ sources }: { sources: SourceRef[] }) {
  const domains = new Map<string, SourceRef[]>()
  if (!sources.length) return null
  for (const source of sources) {
    const entries = domains.get(source.domain) ?? []
    if (!entries.some((entry) => entry.label === source.label)) entries.push(source)
    domains.set(source.domain, entries)
  }
  return (
    <div className="source-badges">
      {[...domains].map(([domain, entries]) => {
        return entries.length === 1 ? (
          <span key={domain} className="source-domain nodrag" title={`${domain}: ${entries[0].label}`}>
            <SourceLink source={entries[0]} label={`${domain}: ${entries[0].label}`} className="source-link">
              <Favicon domain={domain} />
            </SourceLink>
          </span>
        ) : (
          <SourceMenu key={domain} domain={domain} sources={entries} />
        )
      })}
    </div>
  )
}
