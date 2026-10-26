import { memo, useLayoutEffect, useRef, useState, type UIEvent } from 'react'
import { getVisibleRange } from '../table/getVisibleRange'
import { useTableRows } from '../table/useTableRows'
import { TableTabRow } from './TableTabRow'

const ROW_HEIGHT = 32
/** Rows drawn past each edge of the view, so a quick scroll doesn't show a gap before they render. */
const OVERSCAN = 8
const COLUMNS = [
  { id: 'card', label: 'Card' },
  { id: 'status', label: 'Status' },
  { id: 'kind', label: 'Kind' },
  { id: 'group', label: 'Group' },
  { id: 'ref', label: 'Ref' },
]

/**
 * The details panel's Table tab: every card in the open group at any depth, or on the whole canvas, one row each. Only
 * the rows in view are drawn, and the rows ignore positions and selection, so the table doesn't redraw while cards move.
 */
export const TableTab = memo(function TableTab({ root, scope, reveal }: { root: string | null; scope: string; reveal: (id: string) => void }) {
  const rows = useTableRows(root)
  const scroller = useRef<HTMLDivElement>(null)
  const [scrollTop, setScrollTop] = useState(0)
  const [viewportHeight, setViewportHeight] = useState(0)
  const { start, end } = getVisibleRange(scrollTop, viewportHeight, ROW_HEIGHT, rows.length, OVERSCAN)

  // Rounded down to a whole row, so scrolling within a row doesn't redraw the table. The overscan covers the difference.
  const scroll = (event: UIEvent<HTMLDivElement>) => setScrollTop(Math.floor(event.currentTarget.scrollTop / ROW_HEIGHT) * ROW_HEIGHT)

  useLayoutEffect(() => {
    const element = scroller.current

    if (!element) return

    const observer = new ResizeObserver(() => setViewportHeight(element.clientHeight))

    setViewportHeight(element.clientHeight)
    observer.observe(element)

    return () => observer.disconnect()
  }, [])

  return (
    <section className="table-tab" aria-label="Table">
      <p className="table-scope">
        <strong>{scope}</strong>
        <span>
          {rows.length} {rows.length === 1 ? 'card' : 'cards'}
        </span>
      </p>
      <div className="table-grid" role="table" aria-label={`Cards in ${scope}`} aria-rowcount={rows.length + 1}>
        <div role="rowgroup" className="table-head">
          <div role="row" className="table-row" aria-rowindex={1}>
            {COLUMNS.map((column) => (
              <div role="columnheader" key={column.id} className={`table-cell table-${column.id}`}>
                {column.label}
              </div>
            ))}
          </div>
        </div>
        <div role="rowgroup" className="table-scroll" ref={scroller} onScroll={scroll}>
          <div className="table-rows" style={{ height: rows.length * ROW_HEIGHT }}>
            {rows.slice(start, end).map((row, offset) => (
              <TableTabRow key={row.id} row={row} index={start + offset} top={(start + offset) * ROW_HEIGHT} reveal={reveal} />
            ))}
          </div>
          {!rows.length && <p className="table-none">No cards here yet.</p>}
        </div>
      </div>
    </section>
  )
})
