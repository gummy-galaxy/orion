import { getPrimaryRef } from '../model'
import type { QueryRow } from '../persist'
import type { TableRow } from './types'

/** A node from a query's answer as the Table tab lists it, labeled the way the canvas labels an untitled card. */
export function toTableRow(row: QueryRow): TableRow {
  return {
    id: row.id,
    label: row.label || (row.kind === 'component' ? 'Untitled component' : 'Note'),
    kind: row.kind,
    status: row.status,
    group: row.groupLabel,
    ref: row.refs && getPrimaryRef({ refs: row.refs })?.key,
  }
}
