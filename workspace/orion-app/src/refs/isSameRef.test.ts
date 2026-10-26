import { expect, test } from 'vitest'
import { isSameRef } from './isSameRef'

test('refs with ids match by id, whatever their keys say', () => {
  const before = { source: 'github', kind: 'pull', key: 'vocksel/orion#12', id: 'R_1#12' }

  expect(isSameRef(before, { ...before, key: 'gummy-galaxy/orion#12' })).toBe(true)
  expect(isSameRef(before, { ...before, id: 'R_2#12' })).toBe(false)
})

test('refs without an id on both sides match by case-insensitive key', () => {
  const stored = { source: 'github', kind: 'pull', key: 'Vocksel/Orion#12' }

  expect(isSameRef(stored, { ...stored, key: 'vocksel/orion#12', id: 'R_1#12' })).toBe(true)
  expect(isSameRef(stored, { ...stored, key: 'vocksel/orion#13' })).toBe(false)
})

test('refs of different kinds never match', () => {
  const pull = { source: 'github', kind: 'pull', key: 'vocksel/orion#12', id: 'X' }

  expect(isSameRef(pull, { ...pull, kind: 'issue' })).toBe(false)
})
