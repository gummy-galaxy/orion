import { afterEach, expect, test } from 'vitest'
import { patchFor, patchWork } from '../batchEdit'
import { closesOut } from '../celebrate'
import type { AppNode, TaskData } from '../model'
import builtinTypes from './builtinTypes.json'
import { FIGMA_FRAME } from './fixtures/figmaFrame'
import { findState } from './findState'
import { getStateChoices } from './getStateChoices'
import { getStateMeaning } from './getStateMeaning'
import { registerCardTypes } from './registerCardTypes'

afterEach(() => registerCardTypes(builtinTypes))

const card = (data: Partial<TaskData>): TaskData => ({ kind: 'task', label: 'Frame', status: 'todo', ...data })
const frame = (status: string) => card({ type: 'figma.frame', status })

test("reads a state through the card's primary type", () => {
  registerCardTypes([...builtinTypes, FIGMA_FRAME])

  expect(getStateMeaning(frame('approved'))).toBe('done')
  expect(getStateMeaning(frame('drafting'))).toBe('todo')
  expect(getStateMeaning(card({ status: 'review' }))).toBe('review')
})

test('a state the type does not declare is still to do', () => {
  registerCardTypes([...builtinTypes, FIGMA_FRAME])

  expect(getStateMeaning(frame('done'))).toBe('todo')
})

test('a type with no states reads a recorded meaning as itself', () => {
  expect(getStateMeaning(card({ type: 'note', status: 'done' }))).toBe('done')
})

test('finds the state a type declares for a meaning, or the meaning itself', () => {
  registerCardTypes([...builtinTypes, FIGMA_FRAME])

  expect(findState(frame('drafting'), 'done')).toBe('approved')
  expect(findState(frame('drafting'), 'review')).toBe('review')
  expect(findState(card({}), 'done')).toBe('done')
})

test("offers the type's own states, and the shipped ones for a type with none", () => {
  registerCardTypes([...builtinTypes, FIGMA_FRAME])

  expect(getStateChoices(frame('drafting'))).toEqual([
    { value: 'drafting', label: 'Drafting' },
    { value: 'approved', label: 'Approved' },
  ])
  expect(getStateChoices(card({ type: 'note' })).map((choice) => choice.value)).toContain('done')
})

test("a selection marked done records each card's own done state and closes them out", () => {
  registerCardTypes([...builtinTypes, FIGMA_FRAME])

  const nodes = [
    { id: 'a', type: 'task', position: { x: 0, y: 0 }, data: frame('drafting') },
    { id: 'b', type: 'task', position: { x: 0, y: 0 }, data: card({}) },
  ] as AppNode[]
  const next = patchWork(nodes, new Set(['a', 'b']), { status: 'done' })

  expect(next.map((node) => (node.data as TaskData).status)).toEqual(['approved', 'done'])
  expect(closesOut(frame('drafting'), patchFor(frame('drafting'), { status: 'done' }))).toBe(true)
})
