import { expect, it } from 'vitest'
import { RECENT_LIMIT, addRecent, keepExistingNodes, readRecents, recentKey, recentsKey, type Recent } from './recents'

it('keys each workspace separately in the data folder', () => {
  expect(recentsKey('orion')).toBe('palette-recents:orion')
  expect(recentsKey('orion')).not.toBe(recentsKey('other'))
})

it('moves a repeated entry to the front instead of listing it twice', () => {
  const recents: Recent[] = [
    { kind: 'command', id: 'fit' },
    { kind: 'node', id: 'a' },
  ]

  expect(addRecent(recents, { kind: 'node', id: 'a' })).toEqual([
    { kind: 'node', id: 'a' },
    { kind: 'command', id: 'fit' },
  ])
})

it('treats a command and a card with the same id as different entries', () => {
  const recents: Recent[] = [{ kind: 'node', id: 'x' }]

  expect(addRecent(recents, { kind: 'command', id: 'x' })).toHaveLength(2)
  expect(recentKey({ kind: 'command', id: 'x' })).not.toBe(recentKey({ kind: 'node', id: 'x' }))
})

it('keeps only the newest entries', () => {
  const recents: Recent[] = Array.from({ length: RECENT_LIMIT }, (_, i) => ({ kind: 'node', id: `n${i}` }) as Recent)
  const next = addRecent(recents, { kind: 'command', id: 'fit' })

  expect(next).toHaveLength(RECENT_LIMIT)
  expect(next[0]).toEqual({ kind: 'command', id: 'fit' })
  expect(next.at(-1)).toEqual({ kind: 'node', id: `n${RECENT_LIMIT - 2}` })
})

it('forgets cards and groups that no longer exist but keeps commands', () => {
  const recents: Recent[] = [
    { kind: 'node', id: 'gone' },
    { kind: 'command', id: 'fit' },
    { kind: 'node', id: 'here' },
  ]

  expect(keepExistingNodes(recents, new Set(['here']))).toEqual([
    { kind: 'command', id: 'fit' },
    { kind: 'node', id: 'here' },
  ])
})

it('reads a saved list and skips anything malformed', () => {
  expect(
    readRecents([
      { kind: 'command', id: 'fit' },
      { kind: 'other', id: 'x' },
      { kind: 'node' },
      'nope',
      null,
      { kind: 'node', id: 'a' },
    ]),
  ).toEqual([
    { kind: 'command', id: 'fit' },
    { kind: 'node', id: 'a' },
  ])
})

it('reads nothing from a value that is not a list', () => {
  expect(readRecents(undefined)).toEqual([])
  expect(readRecents({})).toEqual([])
  expect(readRecents(null)).toEqual([])
})

it('caps a long saved list at the limit', () => {
  const saved = Array.from({ length: RECENT_LIMIT + 10 }, (_, i) => ({ kind: 'node', id: `n${i}` }))

  expect(readRecents(saved)).toHaveLength(RECENT_LIMIT)
})
