import { expect, test } from 'vitest'
import type { ViewStatus } from '../model'
import { isSameStatuses } from './isSameStatuses'

const statuses = new Map<string, ViewStatus>([
  ['a', 'ready'],
  ['b', 'done'],
])

test('matches the same statuses in a new lookup', () => {
  expect(isSameStatuses(statuses, new Map(statuses))).toBe(true)
})

test('notices a status changing, or a card gaining or losing one', () => {
  expect(isSameStatuses(statuses, new Map([...statuses, ['b', 'active']]))).toBe(false)
  expect(isSameStatuses(statuses, new Map([...statuses, ['c', 'ready']]))).toBe(false)
  expect(isSameStatuses(statuses, new Map([['a', 'ready']]))).toBe(false)
})
