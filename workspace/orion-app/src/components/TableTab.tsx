import { memo } from 'react'
import { useTableRows } from '../table/useTableRows'
import { CardTable } from './CardTable'

/**
 * The details panel's Table tab: every card in the open group at any depth, or on the whole canvas, as `orion serve`
 * lists them. The server answers again only when the rows change, so the table doesn't redraw while cards move.
 */
export const TableTab = memo(function TableTab({ root, scope, reveal }: { root: string | null; scope: string; reveal: (id: string) => void }) {
  return <CardTable rows={useTableRows(root)} scope={scope} reveal={reveal} />
})
