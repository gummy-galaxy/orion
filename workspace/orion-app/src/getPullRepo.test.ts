import { expect, test } from 'vitest'
import { getPullRepo } from './getPullRepo'

test('reads the repository from a pull request key, with or without a host', () => {
  expect(getPullRepo('vocksel/orion#341')).toBe('vocksel/orion')
  expect(getPullRepo('github.example.com/Roblox/avatar#2')).toBe('Roblox/avatar')
})

test('reads nothing from a key that names no pull request', () => {
  expect(getPullRepo('ABC-12')).toBeUndefined()
})
