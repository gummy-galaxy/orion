import { expect, test } from 'vitest'
import { getTableQuery } from './getTableQuery'

test('asks for every card on the canvas at the top level', () => {
  expect(getTableQuery(null)).toEqual({ where: 'kind != "group" and kind != "image"', sort: 'group,label', all: true })
})

test('asks for the cards inside the open group at any depth', () => {
  expect(getTableQuery('release').where).toBe('within = "release" and kind != "group" and kind != "image"')
})
