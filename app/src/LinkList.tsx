import { useState } from 'react'
import type { deriveWork } from './derive'
import { STATUS_LABEL, isTask, type AppNode, type ClusterData, type Link, type TaskData } from './model'

type Direction = 'waits' | 'unblocks' | 'related'
const DIRECTION_LABEL: Record<Direction, string> = { waits: 'Waits on', unblocks: 'Unblocks', related: 'Related' }
const ORIGIN_LABEL = { stack: 'stacked', mention: 'mentioned' }

/** The card's own links, not the chains derived through notes, so each one can be removed where it is listed. */
export function LinkList({
  node,
  work,
  nodeMap,
  links,
  jumpTo,
  addLink,
  removeLink,
  flipLink,
}: {
  node: AppNode
  work: ReturnType<typeof deriveWork>
  nodeMap: Map<string, AppNode>
  links: Link[]
  jumpTo: (id: string) => void
  addLink: (from: string, to: string, kind: Link['kind']) => void
  removeLink: (id: string) => void
  flipLink: (id: string) => void
}) {
  const [direction, setDirection] = useState<Direction>('waits')
  const [query, setQuery] = useState('')
  const ownLinks = links.filter((link) => (link.from === node.id || link.to === node.id) && nodeMap.has(link.from) && nodeMap.has(link.to))
  const groups: Record<Direction, Link[]> = {
    waits: ownLinks.filter((link) => link.kind === 'blocks' && link.to === node.id),
    unblocks: ownLinks.filter((link) => link.kind === 'blocks' && link.from === node.id),
    related: ownLinks.filter((link) => link.kind === 'related'),
  }
  const labelOf = (card: AppNode) => (card.data as TaskData).label || 'Note'
  const joined = new Set(ownLinks.map((link) => (link.from === node.id ? link.to : link.from)))
  const needle = query.trim().toLowerCase()
  const matches = needle
    ? [...nodeMap.values()]
        .filter(isTask)
        .filter((card) => card.id !== node.id && !joined.has(card.id) && labelOf(card).toLowerCase().includes(needle))
        .slice(0, 6)
    : []

  const connect = (other: string) => {
    if (direction === 'unblocks') addLink(node.id, other, 'blocks')
    else addLink(other, node.id, direction === 'waits' ? 'blocks' : 'related')

    setQuery('')
  }

  return (
    <div className="links">
      {(Object.keys(groups) as Direction[]).map((key) => (
        <div key={key}>
          <span className="label-text">{DIRECTION_LABEL[key]}</span>
          {groups[key].length ? (
            <ul>
              {groups[key].map((link) => {
                const id = link.from === node.id ? link.to : link.from
                const other = nodeMap.get(id)!
                const parent = other.parentId ? nodeMap.get(other.parentId) : undefined

                return (
                  <li key={link.id}>
                    <button type="button" className="link" onClick={() => jumpTo(id)}>
                      {labelOf(other)} <span>({STATUS_LABEL[work.status.get(id) ?? 'ready']})</span>
                    </button>
                    <button
                      type="button"
                      className="link link-flip"
                      aria-label={`${link.kind === 'blocks' ? 'Make related' : 'Make blocking'} link to ${labelOf(other)}`}
                      onClick={() => flipLink(link.id)}
                    >
                      {link.kind === 'blocks' ? 'Related' : 'Blocking'}
                    </button>
                    <button
                      type="button"
                      className="link link-remove"
                      aria-label={`Remove link to ${labelOf(other)}`}
                      onClick={() => removeLink(link.id)}
                    >
                      ×
                    </button>
                    {(parent && parent.id !== node.parentId) || link.origin ? (
                      <span className="link-where">
                        {[
                          parent && parent.id !== node.parentId && `in ${(parent.data as ClusterData).label}`,
                          link.origin && ORIGIN_LABEL[link.origin],
                        ]
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
        </div>
      ))}
      <span className="label-text">Add link</span>
      <div className="link-add">
        <select aria-label="Link kind" value={direction} onChange={(event) => setDirection(event.target.value as Direction)}>
          {(Object.keys(DIRECTION_LABEL) as Direction[]).map((key) => (
            <option key={key} value={key}>
              {DIRECTION_LABEL[key]}
            </option>
          ))}
        </select>
        <input
          aria-label="Card to link"
          value={query}
          placeholder="Search cards"
          onChange={(event) => setQuery(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === 'Enter' && matches[0]) connect(matches[0].id)

            if (event.key === 'Escape') setQuery('')
          }}
        />
      </div>
      {needle &&
        (matches.length ? (
          <ul className="link-matches">
            {matches.map((card) => {
              const parent = card.parentId ? nodeMap.get(card.parentId) : undefined

              return (
                <li key={card.id}>
                  <button type="button" className="link" onClick={() => connect(card.id)}>
                    {labelOf(card)}
                  </button>
                  {parent && <span className="link-where">in {(parent.data as ClusterData).label}</span>}
                </li>
              )
            })}
          </ul>
        ) : (
          <p className="facts">No cards match</p>
        ))}
    </div>
  )
}
