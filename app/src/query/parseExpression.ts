/**
 * Spike #102: a port of `cli/src/query/parseExpression.luau`, so the table filters with the same grammar as
 * `orion node query --where`. Shared logic lives in Luau, so the real build asks `orion serve` to evaluate the
 * expression instead of keeping a second copy here.
 */
export type Expression =
  | { kind: 'comparison'; field: string; operator: '=' | '!=' | '~'; value: string }
  | { kind: 'not'; left: Expression }
  | { kind: 'and'; left: Expression; right: Expression }
  | { kind: 'or'; left: Expression; right: Expression }

/** The CLI's fields, plus `who`, which the table shows and the CLI doesn't query yet. */
export const QUERY_FIELDS = ['kind', 'repo', 'status', 'recordedStatus', 'group', 'draft', 'label', 'note', 'pr', 'ref', 'snoozed', 'who']

const SEARCHABLE = new Set(['label', 'note', 'ref'])

export function parseExpression(input: string): Expression {
  let cursor = 0

  const fail = (message: string): never => {
    throw new Error(`query at column ${cursor + 1}: ${message}`)
  }

  const skipSpace = () => {
    while (/\s/.test(input[cursor] ?? '')) cursor++
  }

  const readWord = () => {
    skipSpace()
    const word = input.slice(cursor).match(/^[A-Za-z][A-Za-z0-9]*/)?.[0]

    if (word) cursor += word.length

    return word
  }

  const readKeyword = (keyword: string) => {
    skipSpace()
    const end = cursor + keyword.length

    if (input.slice(cursor, end).toLowerCase() !== keyword || /[\w]/.test(input[end] ?? '')) return false

    cursor = end

    return true
  }

  const readValue = () => {
    skipSpace()
    const quote = input[cursor]

    if (quote !== '"' && quote !== "'") fail('expected a quoted string value')

    cursor++
    let value = ''

    while (cursor < input.length) {
      const character = input[cursor]

      if (character === quote) {
        cursor++

        return value
      }

      if (character === '\\') {
        const next = input[cursor + 1]

        if (next !== quote && next !== '\\') fail('only quote and backslash escapes are supported')

        value += next
        cursor += 2
      } else {
        value += character
        cursor++
      }
    }

    return fail('unterminated quoted string')
  }

  const parsePrimary = (): Expression => {
    skipSpace()

    if (input[cursor] === '(') {
      cursor++
      const expression = parseOr()

      skipSpace()

      if (input[cursor] !== ')') fail("expected ')'")

      cursor++

      return expression
    }

    const field = readWord()

    if (!field) return fail("expected a field or '('")

    if (!QUERY_FIELDS.includes(field)) fail(`unknown field '${field}'`)

    skipSpace()
    let operator: '=' | '!=' | '~'

    if (input.slice(cursor, cursor + 2) === '!=') {
      operator = '!='
      cursor += 2
    } else if (input[cursor] === '=' || input[cursor] === '~') {
      operator = input[cursor] as '=' | '~'
      cursor++
    } else {
      return fail("expected '=', '!=', or '~'")
    }

    if (operator === '~' && !SEARCHABLE.has(field)) fail("'~' is only supported for label, note, and ref")

    const value = readValue()

    if (field === 'draft' && value !== 'true' && value !== 'false') fail("draft must be 'true' or 'false'")

    return { kind: 'comparison', field, operator, value }
  }

  const parseNot = (): Expression => (readKeyword('not') ? { kind: 'not', left: parseNot() } : parsePrimary())

  const parseAnd = (): Expression => {
    let expression = parseNot()

    while (readKeyword('and')) expression = { kind: 'and', left: expression, right: parseNot() }

    return expression
  }

  const parseOr = (): Expression => {
    let expression = parseAnd()

    while (readKeyword('or')) expression = { kind: 'or', left: expression, right: parseAnd() }

    return expression
  }

  const expression = parseOr()

  skipSpace()

  if (cursor < input.length) fail(`unexpected '${input[cursor]}'`)

  return expression
}
