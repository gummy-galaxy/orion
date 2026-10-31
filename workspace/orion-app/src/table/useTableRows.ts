import { useEffect, useState } from 'react'
import { watchQuery } from '../persist'
import { getTableQuery } from './getTableQuery'
import { toTableRow } from './toTableRow'
import type { TableRow } from './types'

/**
 * The cards inside `root` at any depth, or on the whole canvas, as Table tab rows. `orion serve` answers the query and
 * answers again only when a change alters the rows, so dragging or selecting cards doesn't redraw the table. Until the
 * first answer, and after a failed one, the rows stay as they were.
 */
export function useTableRows(root: string | null): TableRow[] {
  const [rows, setRows] = useState<TableRow[]>([])

  useEffect(
    () =>
      watchQuery(getTableQuery(root), (answer) => {
        if ('rows' in answer) setRows(answer.rows.map(toTableRow))
        else console.error('Could not list the cards for the table', answer.error)
      }),
    [root],
  )

  return rows
}
