import { expect, test } from 'vitest'
import { getItemTypes } from './getItemTypes'

const pull = { source: 'github', kind: 'pull', key: 'vocksel/orion#12', type: 'pr' }
const ticket = { source: 'jira', kind: 'issue', key: 'ORN-1', type: 'step' }

test('a card with nothing chosen or attached is a step, or a placeholder when it names a repository', () => {
  expect(getItemTypes({})).toEqual({ primary: 'step', types: ['step'] })
  expect(getItemTypes({ repo: 'vocksel/orion' }).primary).toBe('placeholder')
})

test("a source's type picks the face, and one that supersedes it takes over", () => {
  expect(getItemTypes({ repo: 'vocksel/orion', refs: [ticket] }).primary).toBe('step')
  expect(getItemTypes({ repo: 'vocksel/orion', refs: [ticket, pull] })).toEqual({
    primary: 'pr',
    types: ['pr', 'step'],
  })
})

test("the type a person chose stays the face unless a source's supersedes it, and attached types follow", () => {
  expect(getItemTypes({ type: 'gate', refs: [pull], types: ['note'] })).toEqual({
    primary: 'gate',
    types: ['gate', 'pr', 'note'],
  })
})

test('refs recorded without a type are read by their kind', () => {
  expect(getItemTypes({ refs: [{ source: 'github', kind: 'pull', key: 'vocksel/orion#3' }] }).primary).toBe('pr')
})
