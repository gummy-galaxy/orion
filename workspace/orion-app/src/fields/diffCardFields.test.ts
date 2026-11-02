import { expect, test } from 'vitest'
import { diffCardFields } from './diffCardFields'
import type { TaskData } from '../model'

const card = (extra: Partial<TaskData> = {}): TaskData => ({
  kind: 'task',
  label: 'Ship',
  type: 'step',
  status: 'todo',
  ...extra,
})
const pull = (key: string) => ({ source: 'github', kind: 'pull', key })

test('sends only the fields that changed, with an empty string for one cleared', () => {
  expect(
    diffCardFields(card({ who: 'you', note: 'Old' }), card({ label: 'Ship it', status: 'done', note: 'Old' })),
  ).toEqual({
    label: 'Ship it',
    status: 'done',
    who: '',
  })
})

test('leaves out the kind the server works out from the repository', () => {
  expect(diffCardFields(card(), card({ repo: 'vocksel/orion', type: 'placeholder' }))).toEqual({
    repo: 'vocksel/orion',
  })
})

test('sends a kind given or taken away', () => {
  expect(diffCardFields(card(), card({ type: 'gate' }))).toEqual({ kind: 'gate' })
  expect(diffCardFields(card({ type: 'gate' }), card({ type: 'pr' }))).toEqual({ kind: 'step' })
  expect(diffCardFields(card({ type: 'note' }), card())).toEqual({ kind: 'step' })
})

test('sends the pull request number in place of its ref, and leaves the server its other refs', () => {
  const before = card({ repo: 'vocksel/orion', refs: [pull('vocksel/orion#12')] })

  expect(diffCardFields(before, card({ repo: 'vocksel/orion', refs: [pull('vocksel/orion#14')] }))).toEqual({ pr: 14 })
  expect(diffCardFields(before, card({ repo: 'vocksel/orion' }))).toEqual({ pr: '' })
  expect(
    diffCardFields(before, {
      ...before,
      refs: [pull('vocksel/orion#12'), { source: 'jira', kind: 'issue', key: 'ABC-1' }],
    }),
  ).toEqual({})
})

test('leaves out the close-out flag', () => {
  expect(diffCardFields(card({ status: 'done', celebrate: true }), card({ status: 'done' }))).toEqual({})
})
