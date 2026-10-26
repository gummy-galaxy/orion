import { useAtomValue } from 'jotai'
import { selectAtom } from 'jotai/utils'
import { useMemo } from 'react'
import { nodesAtom, workAtom } from '../state'
import { getTableRows } from './getTableRows'
import { isSameStatuses } from './isSameStatuses'
import { isSameTableNodes } from './isSameTableNodes'
import type { TableRow } from './types'

const tableNodesAtom = selectAtom(nodesAtom, (nodes) => nodes, isSameTableNodes)
const statusesAtom = selectAtom(workAtom, (work) => work.status, isSameStatuses)

/**
 * The cards inside `root` at any depth, or on the whole canvas, as Table tab rows. They come from the app's copy of the
 * canvas through selections that ignore position and selection, so dragging or clicking cards doesn't redraw the table.
 * Once `orion serve` can query and page cards, this asks it for the rows instead, and the table stays as it is.
 */
export function useTableRows(root: string | null): TableRow[] {
  const nodes = useAtomValue(tableNodesAtom)
  const statuses = useAtomValue(statusesAtom)

  return useMemo(() => getTableRows(nodes, statuses, root), [nodes, statuses, root])
}
