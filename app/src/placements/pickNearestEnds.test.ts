import { expect, test } from 'vitest'
import { pickNearestEnds } from './pickNearestEnds'

const centers: Record<string, { x: number; y: number }> = {
  login: { x: 0, y: 0 },
  'login-copy': { x: 1000, y: 0 },
  ship: { x: 1200, y: 0 },
}

test('draws to the copy nearest the other end', () => {
  expect(pickNearestEnds(['login', 'login-copy'], ['ship'], (id) => centers[id])).toEqual({ source: 'login-copy', target: 'ship' })
})

test('draws nothing without both ends', () => {
  expect(pickNearestEnds([], ['ship'], (id) => centers[id])).toBeNull()
})
