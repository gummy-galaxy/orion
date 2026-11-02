import { afterEach, expect, test } from 'vitest'
import builtinTypes from './builtinTypes.json'
import { findCardType } from './findCardType'
import { registerCardTypes } from './registerCardTypes'
import type { CardType } from './types'

const frame: CardType = {
  name: 'figma.frame',
  label: 'Figma frame',
  pack: 'figma',
  supersedes: [],
  fields: [],
  face: { layout: 'card', shows: [] },
  states: [{ name: 'approved', label: 'Approved', means: 'done' }],
  meaning: { isWork: true, canBlock: true, canBeDone: true, doneWhen: 'state' },
}

afterEach(() => registerCardTypes(builtinTypes))

test("the server's declarations replace the shipped ones, so a source's type draws with no app change", () => {
  expect(findCardType('figma.frame')).toBeUndefined()

  registerCardTypes([...builtinTypes, frame])

  expect(findCardType('figma.frame')?.label).toBe('Figma frame')
  expect(findCardType('gate')?.meaning.doneWhen).toBe('inputs')
})

test('a missing or empty list keeps the types already known', () => {
  registerCardTypes(undefined)
  registerCardTypes([])

  expect(findCardType('note')?.face.layout).toBe('note')
})
