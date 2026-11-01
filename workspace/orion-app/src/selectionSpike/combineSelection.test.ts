import { expect, test } from 'vitest'
import { combineSelection } from './combineSelection'

test('replaces, adds to, or takes from the base selection', () => {
  const base = new Set(['a', 'b'])

  expect([...combineSelection(base, ['c'], 'replace')]).toEqual(['c'])
  expect([...combineSelection(base, ['c'], 'add')]).toEqual(['a', 'b', 'c'])
  expect([...combineSelection(base, ['b'], 'subtract')]).toEqual(['a'])
})
