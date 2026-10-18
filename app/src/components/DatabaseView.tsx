import { useMemo, useState } from 'react'
import type { Work } from '../derive'
import { openExternal } from '../external'
import { STATUS_CHOICES, STATUS_LABEL, WHO_CHOICES, type AppNode, type ItemKind, type Status, type TaskData, type Who } from '../model'
import { matchesExpression } from '../query/matchesExpression'
import { parseExpression, type Expression } from '../query/parseExpression'
import { getTableRows } from '../table/getTableRows'
import { sizeLabel } from '../table/sizeLabel'
import { sortRows } from '../table/sortRows'
import type { Sort, SortKey } from '../table/types'
import { DatabaseLabelCell } from './DatabaseLabelCell'
import { StatusIcon } from './StatusIcon'

const KIND_LABEL: Record<ItemKind, string> = {
  pr: 'PR',
  placeholder: 'Placeholder',
  step: 'Step',
  gate: 'Gate',
  note: 'Note',
  component: 'Component',
}

/** Filters a person reaches for first, written in the query grammar so they double as examples of it. */
const PRESETS: { label: string; where: string }[] = [
  { label: 'Ready', where: 'status = "ready"' },
  { label: 'Your move', where: 'who = "you" and not status = "done"' },
  { label: 'Open pull requests', where: 'kind = "pr" and not status = "done"' },
  { label: 'Hide notes', where: 'not kind = "note"' },
]

type Column = { key: SortKey; label: string }

/**
 * Spike #102: the cards in the open group, or the whole canvas, as a table beside the canvas. Edits go through the
 * canvas's own `update`, so they land in its undo history and reach `orion serve` as the same operations.
 */
export function DatabaseView({
  nodes,
  work,
  root,
  title,
  update,
  reveal,
  close,
}: {
  nodes: AppNode[]
  work: Work
  root: string | null
  title: string
  update: (id: string, patch: Partial<TaskData>) => void
  reveal: (id: string) => void
  close: () => void
}) {
  const [where, setWhere] = useState('')
  const [sort, setSort] = useState<Sort | null>(null)
  const allRows = useMemo(() => getTableRows(nodes, work, root), [nodes, work, root])
  const selected = useMemo(() => new Set(nodes.filter((node) => node.selected).map((node) => node.id)), [nodes])

  const parsed = useMemo((): { expression?: Expression; error?: string } => {
    if (!where.trim()) return {}

    try {
      return { expression: parseExpression(where) }
    } catch (error) {
      return { error: (error as Error).message }
    }
  }, [where])

  const rows = useMemo(() => {
    const { expression } = parsed
    const matching = expression ? allRows.filter((row) => matchesExpression(row, expression)) : allRows

    return sortRows(matching, sort)
  }, [allRows, parsed, sort])

  // Columns a source fills in show only when some card here has a value for them.
  const columns = useMemo((): Column[] => {
    const hasPriority = allRows.some((row) => row.priority)
    const hasSize = allRows.some((row) => row.lines !== undefined)

    return [
      { key: 'label', label: 'Label' },
      { key: 'status', label: 'Status' },
      { key: 'kind', label: 'Kind' },
      { key: 'group', label: 'Group' },
      { key: 'refs', label: 'Refs' },
      ...(hasPriority ? [{ key: 'priority', label: 'Priority' } as Column] : []),
      ...(hasSize ? [{ key: 'size', label: 'Size' } as Column] : []),
      { key: 'who', label: 'Whose move' },
    ]
  }, [allRows])

  const toggleSort = (key: SortKey) =>
    setSort((current) => (current?.key !== key ? { key, direction: 'asc' } : current.direction === 'asc' ? { key, direction: 'desc' } : null))

  return (
    <section className="database-view" aria-label="Table view">
      <header className="db-head">
        <div className="db-title">
          <strong>{title}</strong>
          <span className="db-count">{rows.length === allRows.length ? `${allRows.length} cards` : `${rows.length} of ${allRows.length} cards`}</span>
        </div>
        <button type="button" className="side-hide" onClick={close} aria-label="Close the table" title="Close the table">
          ×
        </button>
      </header>
      <div className="db-filter">
        <input
          className={parsed.error ? 'db-where has-error' : 'db-where'}
          value={where}
          spellCheck={false}
          placeholder='Filter, such as status = "ready" and not kind = "note"'
          aria-label="Filter with a query"
          onChange={(event) => setWhere(event.target.value)}
        />
        <div className="db-presets">
          {PRESETS.map((preset) => (
            <button
              type="button"
              key={preset.label}
              className={where === preset.where ? 'db-preset is-on' : 'db-preset'}
              onClick={() => setWhere(where === preset.where ? '' : preset.where)}
            >
              {preset.label}
            </button>
          ))}
        </div>
        {parsed.error && (
          <p className="db-error" role="alert">
            {parsed.error}
          </p>
        )}
      </div>
      <div className="db-scroll">
        <table className="db-table">
          <thead>
            <tr>
              {columns.map((column) => (
                <th key={column.key} aria-sort={sort?.key === column.key ? (sort.direction === 'asc' ? 'ascending' : 'descending') : undefined}>
                  <button type="button" onClick={() => toggleSort(column.key)}>
                    {column.label}
                    <span className="db-sort" aria-hidden="true">
                      {sort?.key === column.key ? (sort.direction === 'asc' ? '▲' : '▼') : ''}
                    </span>
                  </button>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr
                key={row.id}
                data-id={row.id}
                className={selected.has(row.id) ? 'is-selected' : undefined}
                onClick={(event) => {
                  if (!(event.target as HTMLElement).closest('input, select, a')) reveal(row.id)
                }}
              >
                {columns.map((column) => {
                  switch (column.key) {
                    case 'label':
                      return (
                        <DatabaseLabelCell
                          key="label"
                          label={row.label}
                          placeholder={row.kind === 'note' ? 'Note' : 'Untitled'}
                          save={(label) => update(row.id, { label })}
                        />
                      )
                    case 'status':
                      return (
                        <td key="status" className="db-status">
                          {row.status ? (
                            <label
                              className="db-status-pill"
                              title={`Recorded as ${STATUS_CHOICES.find((choice) => choice.value === row.recordedStatus)?.label}`}
                            >
                              <StatusIcon status={row.status} />
                              <span>{STATUS_LABEL[row.status]}</span>
                              <select
                                aria-label="Status"
                                value={row.recordedStatus}
                                onChange={(event) => update(row.id, { status: event.target.value as Status })}
                              >
                                {STATUS_CHOICES.map((choice) => (
                                  <option key={choice.value} value={choice.value}>
                                    {choice.label}
                                  </option>
                                ))}
                              </select>
                            </label>
                          ) : (
                            <span className="db-empty">—</span>
                          )}
                        </td>
                      )
                    case 'kind':
                      return (
                        <td key="kind" className="db-muted">
                          {KIND_LABEL[row.kind]}
                        </td>
                      )
                    case 'group':
                      return (
                        <td key="group" className="db-muted db-group" title={row.groupPath}>
                          {row.groupPath || <span className="db-empty">—</span>}
                        </td>
                      )
                    case 'refs':
                      return (
                        <td key="refs" className="db-refs">
                          {row.refs.length ? (
                            row.refs.map((ref) =>
                              ref.url ? (
                                <a
                                  key={ref.key}
                                  href={ref.url}
                                  onClick={(event) => {
                                    event.preventDefault()
                                    openExternal(ref.url!)
                                  }}
                                >
                                  {ref.key}
                                </a>
                              ) : (
                                <span key={ref.key}>{ref.key}</span>
                              ),
                            )
                          ) : (
                            <span className="db-empty">—</span>
                          )}
                        </td>
                      )
                    case 'priority':
                      return <td key="priority">{row.priority ?? <span className="db-empty">—</span>}</td>
                    case 'size':
                      return (
                        <td key="size" className="db-size">
                          {row.lines === undefined ? (
                            <span className="db-empty">—</span>
                          ) : (
                            <>
                              <strong>{sizeLabel(row.lines)}</strong> <span className="db-muted">{row.lines}</span>
                            </>
                          )}
                        </td>
                      )
                    case 'who':
                      return (
                        <td key="who" className="db-who">
                          {row.kind === 'note' || row.kind === 'component' ? (
                            <span className="db-empty">—</span>
                          ) : (
                            <select
                              aria-label="Whose move"
                              value={row.who ?? ''}
                              onChange={(event) => update(row.id, { who: (event.target.value || undefined) as Who | undefined })}
                            >
                              <option value="">—</option>
                              {WHO_CHOICES.map((choice) => (
                                <option key={choice.value} value={choice.value}>
                                  {choice.label}
                                </option>
                              ))}
                            </select>
                          )}
                        </td>
                      )
                  }
                })}
              </tr>
            ))}
          </tbody>
        </table>
        {!rows.length && <p className="db-none">{allRows.length ? 'No cards match this filter.' : 'No cards here yet.'}</p>}
      </div>
    </section>
  )
}
