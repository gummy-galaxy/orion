import type { Sort, TableRow } from './types'

const STATUS_ORDER = ['active', 'review', 'ready', 'blocked', 'deferred', 'done']
const PRIORITY_ORDER = ['highest', 'high', 'medium', 'low', 'lowest']
const WHO_ORDER = ['you', 'review', 'ci']

/** Missing values sort last in either direction, so a sort never buries what has a value under what doesn't. */
const rank = (order: string[], value: string | undefined) => (value === undefined ? undefined : order.indexOf(value.toLowerCase()))

function sortValue(row: TableRow, key: Sort['key']): string | number | undefined {
  switch (key) {
    case 'label':
      return row.label.toLowerCase()
    case 'status':
      return rank(STATUS_ORDER, row.status)
    case 'kind':
      return row.kind
    case 'group':
      return row.groupPath.toLowerCase() || undefined
    case 'refs':
      return row.refs[0]?.key.toLowerCase()
    case 'priority':
      return rank(PRIORITY_ORDER, row.priority)
    case 'size':
      return row.lines
    case 'who':
      return rank(WHO_ORDER, row.who)
  }
}

/** Rows in the order a sort asks for, keeping their canvas order where values tie. */
export function sortRows(rows: TableRow[], sort: Sort | null): TableRow[] {
  if (!sort) return rows

  const sign = sort.direction === 'asc' ? 1 : -1

  return rows
    .map((row, index) => ({ row, index, value: sortValue(row, sort.key) }))
    .sort((a, b) => {
      if (a.value === b.value) return a.index - b.index

      if (a.value === undefined) return 1

      if (b.value === undefined) return -1

      return (a.value < b.value ? -1 : 1) * sign
    })
    .map(({ row }) => row)
}
