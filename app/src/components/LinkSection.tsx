import type { deriveWork } from '../derive'
import { STATUS_LABEL, cardLabel, type AppNode, type ClusterData, type Link } from '../model'
import { StatusIcon } from './StatusIcon'

const ORIGIN_LABEL = { stack: 'stacked', mention: 'mentioned' }

/** One collapsible list of a card's links. It stays closed until opened, with its count in the summary. */
export function LinkSection({
  title,
  node,
  work,
  nodeMap,
  links,
  jumpTo,
  removeLink,
  flipLink,
}: {
  title: string
  node: AppNode
  work: ReturnType<typeof deriveWork>
  nodeMap: Map<string, AppNode>
  links: Link[]
  jumpTo: (id: string) => void
  removeLink: (id: string) => void
  flipLink: (id: string) => void
}) {
  return (
    <details className="link-section">
      <summary>
        <span>{title}</span>
        <span className="link-count">{links.length}</span>
      </summary>
      {links.length ? (
        <ul className="links">
          {links.map((link) => {
            const id = link.from === node.id ? link.to : link.from
            const other = nodeMap.get(id)!
            const parent = other.parentId ? nodeMap.get(other.parentId) : undefined
            const status = work.status.get(id) ?? 'ready'

            return (
              <li key={link.id}>
                <button type="button" className="link" onClick={() => jumpTo(id)}>
                  {cardLabel(other)}{' '}
                  <span className="link-status">
                    <StatusIcon status={status} />
                    {STATUS_LABEL[status]}
                  </span>
                </button>
                <button
                  type="button"
                  className="link link-flip"
                  aria-label={`${link.kind === 'blocks' ? 'Make related' : 'Make blocking'} link to ${cardLabel(other)}`}
                  onClick={() => flipLink(link.id)}
                >
                  {link.kind === 'blocks' ? 'Related' : 'Blocking'}
                </button>
                <button
                  type="button"
                  className="link link-remove"
                  aria-label={`Remove link to ${cardLabel(other)}`}
                  onClick={() => removeLink(link.id)}
                >
                  ×
                </button>
                {(parent && parent.id !== node.parentId) || link.origin ? (
                  <span className="link-where">
                    {[parent && parent.id !== node.parentId && `in ${(parent.data as ClusterData).label}`, link.origin && ORIGIN_LABEL[link.origin]]
                      .filter(Boolean)
                      .join(' · ')}
                  </span>
                ) : null}
              </li>
            )
          })}
        </ul>
      ) : (
        <p className="facts">Nothing</p>
      )}
    </details>
  )
}
