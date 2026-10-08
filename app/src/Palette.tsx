import { useEffect, useMemo, useRef, useState } from 'react'
import { ancestors, byId, isCluster, getTaskTag, type AppNode } from './model'

export type Command = { id: string; label: string; detail: string; hint?: string; run: () => void }
type Props = { nodes: AppNode[]; commands: Command[]; jumpTo: (id: string) => void; open: (id: string) => void; close: () => void }
type Match = { score: number; indices: number[] }
type NodeResult = { kind: 'node'; node: AppNode; path: string; score: number; labelMatch: number[]; tagMatch: number[]; idMatch: boolean }
type CommandResult = { kind: 'command'; command: Command; score: number; labelMatch: number[] }
type Result = NodeResult | CommandResult

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
  for (const character of needle) {
    const at = haystack.indexOf(character, from)
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
  return [...value].map((character, i) => (picked.has(i) ? <mark key={i}>{character}</mark> : character))
}

export function Palette({ nodes, commands, jumpTo, open, close }: Props) {
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
      const nodeResults = nodes
        .filter((node) => isCluster(node) || (node.type === 'task' && node.data.who === 'you'))
        .sort((a, b) => Number(isCluster(b)) - Number(isCluster(a)))
        .slice(0, 50)
        .map((node): NodeResult => ({
          kind: 'node',
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
      return nodeResults
    }
    const commandResults = commands
      .map((command): CommandResult | null => {
        const labelMatch = match(term, command.label)
        if (!labelMatch) return null
        return { kind: 'command', command, score: labelMatch.score, labelMatch: labelMatch.indices }
      })
      .filter((result): result is CommandResult => result !== null)
    const nodeResults = nodes
      .map((node): NodeResult | null => {
        const labelMatch = match(term, node.data.label)
        const tagMatch = node.type === 'task' ? match(term, getTaskTag(node.data)) : null
        const idMatch = node.type === 'task' ? match(term, node.id) : null
        const score = Math.max(labelMatch?.score ?? -Infinity, tagMatch?.score ?? -Infinity, idMatch?.score ?? -Infinity)
        if (score === -Infinity) return null
        return {
          kind: 'node',
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
      .filter((result): result is NodeResult => result !== null)
      .sort((a, b) => b.score - a.score || a.node.data.label.length - b.node.data.label.length || a.node.data.label.localeCompare(b.node.data.label))
      .slice(0, 50)
    return [...commandResults, ...nodeResults]
  }, [nodes, query, commands])

  useEffect(() => {
    list.current?.querySelector('[aria-selected="true"]')?.scrollIntoView({ block: 'nearest' })
  }, [selected, results])

  const pick = (result: Result) => {
    close()
    if (result.kind === 'command') {
      result.command.run()
      return
    }
    if (isCluster(result.node)) open(result.node.id)
    else jumpTo(result.node.id)
  }

  const onKeyDown = (event: React.KeyboardEvent) => {
    if (event.key === 'Escape') {
      event.preventDefault()
      event.stopPropagation()
      close()
    } else if (event.key === 'Tab') {
      const buttons = list.current?.querySelectorAll<HTMLButtonElement>('button')
      const last = buttons?.[buttons.length - 1]
      if (event.shiftKey && event.target === input.current) {
        event.preventDefault()
        last?.focus()
      } else if (!event.shiftKey && (!last || event.target === last)) {
        event.preventDefault()
        input.current?.focus()
      }
    } else if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault()
      event.stopPropagation()
      if (results.length) setSelected((index) => (index + (event.key === 'ArrowDown' ? 1 : -1) + results.length) % results.length)
      input.current?.focus()
    } else if (event.key === 'Enter' && event.target === input.current) {
      event.preventDefault()
      event.stopPropagation()
      if (results[selected]) pick(results[selected])
    }
  }

  return (
    <div className="palette-backdrop" onMouseDown={(event) => event.target === event.currentTarget && close()}>
      <div className="palette panel" role="dialog" aria-modal="true" aria-label="Search canvas" onKeyDown={onKeyDown}>
        <input
          ref={input}
          type="search"
          role="combobox"
          aria-label="Search groups, cards, and actions"
          aria-expanded="true"
          aria-controls="palette-results"
          aria-activedescendant={results[selected] ? `palette-result-${selected}` : undefined}
          placeholder="Search groups, cards, PRs, actions…"
          value={query}
          onChange={(event) => {
            setQuery(event.target.value)
            setSelected(0)
          }}
        />
        <div ref={list} className="palette-results" id="palette-results" role="listbox">
          {results.map((result, i) => {
            if (result.kind === 'command') {
              return (
                <button
                  key={'command:' + result.command.id}
                  id={`palette-result-${i}`}
                  type="button"
                  role="option"
                  aria-selected={i === selected}
                  className="palette-result"
                  onMouseEnter={() => setSelected(i)}
                  onMouseDown={(event) => event.preventDefault()}
                  onClick={() => pick(result)}
                >
                  <span className="palette-kind">Action</span>
                  <span className="palette-details">
                    <span className="palette-label">{highlighted(result.command.label, result.labelMatch)}</span>
                    <span className="palette-path">
                      {result.command.detail}
                      {result.command.hint && <> · {result.command.hint}</>}
                    </span>
                  </span>
                </button>
              )
            }
            const { node } = result
            const tag = node.type === 'task' ? getTaskTag(node.data) : null
            return (
              <button
                key={node.id}
                id={`palette-result-${i}`}
                type="button"
                role="option"
                aria-selected={i === selected}
                className="palette-result"
                onMouseEnter={() => setSelected(i)}
                onMouseDown={(event) => event.preventDefault()}
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
