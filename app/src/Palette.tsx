import { useEffect, useMemo, useRef, useState } from 'react'
import { ancestors, byId, isCluster, taskTag, type AppNode } from './model'

type Props = { nodes: AppNode[]; jumpTo: (id: string) => void; open: (id: string) => void; close: () => void }
type Match = { score: number; indices: number[] }
type Result = { node: AppNode; path: string; score: number; labelMatch: number[]; tagMatch: number[]; idMatch: boolean }

function match(query: string, value: string): Match | null {
  const needle = query.toLowerCase()
  const haystack = value.toLowerCase()
  // A contiguous match beats any scattered one, and more so at a word start.
  const at = haystack.indexOf(needle)
  if (at >= 0) {
    const isWordStart = at === 0 || !/[a-z0-9]/i.test(value[at - 1])
    return { score: 1000 + (isWordStart ? 200 : 0) - at, indices: Array.from({ length: needle.length }, (_, i) => at + i) }
  }
  const indices: number[] = []
  let score = 0
  let from = 0
  for (const char of needle) {
    const at = haystack.indexOf(char, from)
    if (at < 0) return null
    indices.push(at)
    score += 10
    if (at === 0 || !/[a-z0-9]/i.test(value[at - 1])) score += 8
    if (indices.length > 1 && at === indices[indices.length - 2] + 1) score += 6
    from = at + 1
  }
  return { score: score - (indices[0] ?? 0), indices }
}

function highlighted(value: string, indices: number[]) {
  const picked = new Set(indices)
  return [...value].map((char, i) => (picked.has(i) ? <mark key={i}>{char}</mark> : char))
}

export function Palette({ nodes, jumpTo, open, close }: Props) {
  const [query, setQuery] = useState('')
  const [selected, setSelected] = useState(0)
  const input = useRef<HTMLInputElement>(null)
  const list = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const previous = document.activeElement instanceof HTMLElement ? document.activeElement : null
    input.current?.focus()
    return () => previous?.focus()
  }, [])

  const results = useMemo(() => {
    const map = byId(nodes)
    const term = query.trim()
    if (!term) {
      return nodes
        .filter((n) => isCluster(n) || (n.type === 'task' && n.data.who === 'you'))
        .sort((a, b) => Number(isCluster(b)) - Number(isCluster(a)))
        .slice(0, 50)
        .map((node): Result => ({
          node,
          path: ancestors(node.id, map)
            .reverse()
            .map((id) => map.get(id)?.data.label)
            .filter(Boolean)
            .join(' › '),
          score: 0,
          labelMatch: [],
          tagMatch: [],
          idMatch: false,
        }))
    }
    return nodes
      .map((node): Result | null => {
        const labelMatch = match(term, node.data.label)
        const tagMatch = node.type === 'task' ? match(term, taskTag(node.data)) : null
        const idMatch = node.type === 'task' ? match(term, node.id) : null
        const score = Math.max(labelMatch?.score ?? -Infinity, tagMatch?.score ?? -Infinity, idMatch?.score ?? -Infinity)
        if (score === -Infinity) return null
        return {
          node,
          path: ancestors(node.id, map)
            .reverse()
            .map((id) => map.get(id)?.data.label)
            .filter(Boolean)
            .join(' › '),
          score,
          labelMatch: labelMatch?.indices ?? [],
          tagMatch: tagMatch?.indices ?? [],
          idMatch: !!idMatch,
        }
      })
      .filter((result): result is Result => result !== null)
      .sort((a, b) => b.score - a.score || a.node.data.label.length - b.node.data.label.length || a.node.data.label.localeCompare(b.node.data.label))
      .slice(0, 50)
  }, [nodes, query])

  useEffect(() => {
    list.current?.querySelector('[aria-selected="true"]')?.scrollIntoView({ block: 'nearest' })
  }, [selected, results])

  const pick = (result: Result) => {
    close()
    if (isCluster(result.node)) open(result.node.id)
    else jumpTo(result.node.id)
  }

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      e.preventDefault()
      e.stopPropagation()
      close()
    } else if (e.key === 'Tab') {
      const buttons = list.current?.querySelectorAll<HTMLButtonElement>('button')
      const last = buttons?.[buttons.length - 1]
      if (e.shiftKey && e.target === input.current) {
        e.preventDefault()
        last?.focus()
      } else if (!e.shiftKey && (!last || e.target === last)) {
        e.preventDefault()
        input.current?.focus()
      }
    } else if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault()
      e.stopPropagation()
      if (results.length) setSelected((index) => (index + (e.key === 'ArrowDown' ? 1 : -1) + results.length) % results.length)
      input.current?.focus()
    } else if (e.key === 'Enter' && e.target === input.current) {
      e.preventDefault()
      e.stopPropagation()
      if (results[selected]) pick(results[selected])
    }
  }

  return (
    <div className="palette-backdrop" onMouseDown={(e) => e.target === e.currentTarget && close()}>
      <div className="palette panel" role="dialog" aria-modal="true" aria-label="Search canvas" onKeyDown={onKeyDown}>
        <input
          ref={input}
          type="search"
          role="combobox"
          aria-label="Search groups and cards"
          aria-expanded="true"
          aria-controls="palette-results"
          aria-activedescendant={results[selected] ? `palette-result-${selected}` : undefined}
          placeholder="Search groups, cards, PRs…"
          value={query}
          onChange={(e) => {
            setQuery(e.target.value)
            setSelected(0)
          }}
        />
        <div ref={list} className="palette-results" id="palette-results" role="listbox">
          {results.map((result, i) => {
            const { node } = result
            const tag = node.type === 'task' ? taskTag(node.data) : null
            return (
              <button
                key={node.id}
                id={`palette-result-${i}`}
                type="button"
                role="option"
                aria-selected={i === selected}
                className="palette-result"
                onMouseEnter={() => setSelected(i)}
                onMouseDown={(e) => e.preventDefault()}
                onClick={() => pick(result)}
              >
                <span className="palette-kind">{isCluster(node) ? 'Group' : node.data.itemKind === 'note' ? 'Note' : 'Card'}</span>
                <span className="palette-details">
                  <span className="palette-label">
                    {highlighted(
                      node.data.label || (node.type === 'task' && node.data.itemKind === 'note' ? 'Untitled note' : ''),
                      result.labelMatch,
                    )}
                  </span>
                  <span className="palette-path">
                    {result.path || 'All work'}
                    {tag && <> · {highlighted(tag, result.tagMatch)}</>}
                    {result.idMatch && <> · {node.id}</>}
                  </span>
                </span>
              </button>
            )
          })}
          {!results.length && <div className="palette-empty">No matches</div>}
        </div>
      </div>
    </div>
  )
}
