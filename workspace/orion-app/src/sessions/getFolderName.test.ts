import { expect, test } from 'vitest'
import { getFolderName } from './getFolderName'

test('a folder shows by its last name on any platform', () => {
  expect(getFolderName('/Users/me/git/orion/')).toBe('orion')
  expect(getFolderName('C:\\work\\orion')).toBe('orion')
  expect(getFolderName(null)).toBe('its folder')
})
