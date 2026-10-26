import { afterEach, expect, test } from 'vitest'
import type { TaskData } from '../model'
import builtinTypes from './builtinTypes.json'
import { FIGMA_FRAME } from './fixtures/figmaFrame'
import { getFieldValues } from './getFieldValues'
import { registerCardTypes } from './registerCardTypes'

afterEach(() => registerCardTypes(builtinTypes))

const card = (data: Partial<TaskData>): TaskData => ({ kind: 'task', label: 'Frame', status: 'todo', ...data })

test("lists the primary type's fields first, each once, with the card's value or the default", () => {
  registerCardTypes([...builtinTypes, FIGMA_FRAME])

  const entries = getFieldValues(card({ who: 'you', types: ['figma.frame'], fields: { screens: 4 } }))

  expect(entries.map(({ type, field, value }) => [type, field.name, value])).toEqual([
    ['step', 'who', 'you'],
    ['figma.frame', 'file', undefined],
    ['figma.frame', 'screens', 4],
    ['figma.frame', 'shared', undefined],
    ['figma.frame', 'due', undefined],
    ['figma.frame', 'stage', 'draft'],
  ])
})

test('a type nothing registers adds no fields', () => {
  expect(getFieldValues(card({ types: ['figma.frame'] })).map((entry) => entry.field.name)).toEqual(['who'])
})
