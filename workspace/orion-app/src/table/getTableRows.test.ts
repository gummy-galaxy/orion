import { expect, test } from 'vitest'
import type { ViewStatus } from '../model'
import { card } from './fixtures/card'
import { group } from './fixtures/group'
import { getTableRows } from './getTableRows'

const nodes = [
  group('outer', 'Outer'),
  group('inner', 'Inner', 'outer'),
  card('deep', 'Deep work', 'inner'),
  card('shallow', 'Shallow work', 'outer'),
  card('loose', 'Loose work', undefined, 'pr', [
    { source: 'github', kind: 'pull', key: 'gummy-galaxy/orion#1', url: 'https://github.com/gummy-galaxy/orion/pull/1' },
  ]),
  card('note', '', 'outer', 'note'),
]
const statuses = new Map<string, ViewStatus>([['deep', 'blocked']])

test('lists every card on the canvas, loose cards first, then by group and label', () => {
  expect(getTableRows(nodes, statuses, null).map((row) => row.id)).toEqual(['loose', 'note', 'shallow', 'deep'])
})

test('lists the cards inside the open group at any depth, with groups below it', () => {
  const rows = getTableRows(nodes, statuses, 'outer')

  expect(rows.map((row) => [row.id, row.groups])).toEqual([
    ['note', []],
    ['shallow', []],
    ['deep', ['Inner']],
  ])
})

test("gives work its derived status, ready when there's none, and leaves notes without one", () => {
  const rows = new Map(getTableRows(nodes, statuses, null).map((row) => [row.id, row]))

  expect(rows.get('deep')?.status).toBe('blocked')
  expect(rows.get('shallow')?.status).toBe('ready')
  expect(rows.get('note')?.status).toBeUndefined()
})

test("labels a note that has none, and carries a card's main ref", () => {
  const rows = new Map(getTableRows(nodes, statuses, null).map((row) => [row.id, row]))

  expect(rows.get('note')?.label).toBe('Note')
  expect(rows.get('loose')?.ref).toBe('gummy-galaxy/orion#1')
})
