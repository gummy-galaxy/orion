import type { Expression } from './parseExpression'
import type { TableRow } from '../table/types'

function getField(row: TableRow, field: string): string | undefined {
  switch (field) {
    case 'kind':
      return row.kind
    case 'status':
      return row.status
    case 'recordedStatus':
      return row.recordedStatus
    case 'snoozed':
      return String(row.snoozed)
    case 'repo':
      return row.repo
    case 'label':
      return row.label
    case 'note':
      return row.note
    case 'pr':
      return row.pr
    case 'draft':
      return row.draft
    case 'who':
      return row.who
    default:
      return undefined
  }
}

/**
 * Spike #102: a port of `cli/src/query/matchesExpression.luau`. A missing field never matches, even under `not`. One
 * difference: `group` matches a group's label as well as its id, since the table never shows ids.
 */
export function matchesExpression(row: TableRow, expression: Expression): boolean {
  const evaluate = (node: Expression): boolean | undefined => {
    if (node.kind === 'not') {
      const result = evaluate(node.left)

      return result === undefined ? undefined : !result
    }

    if (node.kind === 'and' || node.kind === 'or') {
      const left = evaluate(node.left)
      const right = evaluate(node.right)
      const decisive = node.kind === 'and' ? false : true

      if (left === decisive || right === decisive) return decisive

      return left === undefined || right === undefined ? undefined : !decisive
    }

    const value = node.value.toLowerCase()

    if (node.field === 'ref') {
      if (!row.refs.length) return undefined

      for (const ref of row.refs) {
        const key = ref.key.toLowerCase()

        if (node.operator === '~' && key.includes(value)) return true

        if (key === value) return node.operator === '='
      }

      return node.operator === '!='
    }

    if (node.field === 'group') {
      if (!row.groupId) return undefined

      const same = row.groupId === node.value || row.groups.at(-1) === node.value

      return node.operator === '=' ? same : !same
    }

    const actual = getField(row, node.field)

    if (actual === undefined) return undefined

    if (node.operator === '~') return actual.toLowerCase().includes(value)

    return node.operator === '=' ? actual === node.value : actual !== node.value
  }

  return evaluate(expression) === true
}
