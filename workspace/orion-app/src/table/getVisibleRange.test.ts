import { expect, test } from 'vitest'
import { getVisibleRange } from './getVisibleRange'

test('draws the rows in view and the overscan past each edge', () => {
  expect(getVisibleRange(320, 200, 32, 100, 2)).toEqual({ start: 8, end: 19 })
})

test('stops at the first and last rows', () => {
  expect(getVisibleRange(0, 200, 32, 100, 4)).toEqual({ start: 0, end: 11 })
  expect(getVisibleRange(3000, 200, 32, 100, 4)).toEqual({ start: 89, end: 100 })
})

test('draws nothing when the list is empty or scrolled past its end', () => {
  expect(getVisibleRange(0, 200, 32, 0, 4)).toEqual({ start: 0, end: 0 })
  expect(getVisibleRange(9000, 200, 32, 10, 4)).toEqual({ start: 10, end: 10 })
})
