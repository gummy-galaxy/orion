import { useState } from 'react'
import { DIRECTION_LABEL, type Direction } from '../linkDirection'
import { cardLabel, isTask, type AppNode, type ClusterData, type Link } from '../model'

/** Searches for another card and links it to this one, in the direction picked. */
export function LinkAdd({
  node,
  nodeMap,
  joined,
  addLink,
}: {
  node: AppNode
  nodeMap: Map<string, AppNode>
  /** Cards this one already has a link with, which the search leaves out. */
  joined: Set<string>
  addLink: (from: string, to: string, kind: Link['kind']) => void
}) {
  const [direction, setDirection] = useState<Direction>('waits')
  const [query, setQuery] = useState('')
  const needle = query.trim().toLowerCase()
  const matches = needle
    ? [...nodeMap.values()]
        .filter(isTask)
        .filter((card) => card.id !== node.id && !joined.has(card.id) && cardLabel(card).toLowerCase().includes(needle))
        .slice(0, 6)
    : []

  const connect = (other: string) => {
    if (direction === 'unblocks') addLink(node.id, other, 'blocks')
    else addLink(other, node.id, direction === 'waits' ? 'blocks' : 'related')

    setQuery('')
  }

  return (
    <details className="link-section">
      <summary>
        <span>Add link</span>
      </summary>
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
                    {cardLabel(card)}
                  </button>
                  {parent && <span className="link-where">in {(parent.data as ClusterData).label}</span>}
                </li>
              )
            })}
          </ul>
        ) : (
          <p className="facts">No cards match</p>
        ))}
    </details>
  )
}
