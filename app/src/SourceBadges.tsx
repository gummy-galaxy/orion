import type { SourceRef } from './derive'
import { Favicon } from './Favicon'
import { SourceLink } from './SourceLink'
import { SourceMenu } from './SourceMenu'

export function SourceBadges({ sources, inBubble = false }: { sources: SourceRef[]; inBubble?: boolean }) {
  const domains = new Map<string, SourceRef[]>()
  for (const source of sources.length ? sources : [{ domain: 'orion', label: 'Orion' }]) {
    const entries = domains.get(source.domain) ?? []
    if (!entries.some((entry) => entry.label === source.label)) entries.push(source)
    domains.set(source.domain, entries)
  }
  return (
    <div className={`source-badges${inBubble ? ' in-bubble' : ''}`}>
      {[...domains].map(([domain, entries]) => {
        const name = domain === 'orion' ? 'Orion' : domain
        return entries.length === 1 ? (
          <span key={domain} className="source-domain nodrag" title={`${name}: ${entries[0].label}`}>
            <SourceLink source={entries[0]} label={`${name}: ${entries[0].label}`} className="source-link">
              <Favicon domain={domain} />
            </SourceLink>
          </span>
        ) : (
          <SourceMenu key={domain} domain={domain} name={name} sources={entries} />
        )
      })}
    </div>
  )
}
