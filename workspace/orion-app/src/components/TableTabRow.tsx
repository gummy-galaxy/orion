import { findCardType } from '../cardTypes/findCardType'
import { STATUS_LABEL } from '../model'
import type { TableRow } from '../table/types'
import { StatusIcon } from './StatusIcon'

const EMPTY = <span className="table-empty">—</span>

/** One card in the Table tab, placed `top` pixels down the list. Its label shows the card on the canvas. */
export function TableTabRow({
  row,
  index,
  top,
  reveal,
}: {
  row: TableRow
  index: number
  top: number
  reveal: (id: string) => void
}) {
  // The header is row 1, so the cards count from 2.
  return (
    <div role="row" className="table-row" aria-rowindex={index + 2} style={{ top }}>
      <div role="cell" className="table-cell table-card">
        <button type="button" onClick={() => reveal(row.id)} title="Show on the canvas">
          {row.label}
        </button>
      </div>
      <div role="cell" className="table-cell table-status">
        {row.status ? (
          <>
            <StatusIcon status={row.status} />
            {STATUS_LABEL[row.status]}
          </>
        ) : (
          EMPTY
        )}
      </div>
      <div role="cell" className="table-cell table-kind">
        {findCardType(row.kind)?.label ?? row.kind}
      </div>
      <div role="cell" className="table-cell table-group" title={row.group || undefined}>
        {row.group || EMPTY}
      </div>
      <div role="cell" className="table-cell table-ref" title={row.ref}>
        {row.ref ?? EMPTY}
      </div>
    </div>
  )
}
