import { expect, test } from 'vitest'
import { toTableRow } from './toTableRow'

test('keeps the fields the table shows', () => {
  expect(
    toTableRow({
      id: 'card',
      kind: 'pr',
      label: 'Fix the query',
      status: 'review',
      group: 'docs',
      groupLabel: 'Docs',
      refs: [
        { source: 'jira', kind: 'issue', key: 'ABC-12' },
        {
          source: 'github',
          kind: 'pull',
          key: 'gummy-galaxy/orion#86',
          url: 'https://github.com/gummy-galaxy/orion/pull/86',
        },
      ],
    }),
  ).toEqual({
    id: 'card',
    label: 'Fix the query',
    kind: 'pr',
    status: 'review',
    group: 'Docs',
    ref: 'gummy-galaxy/orion#86',
  })
})

test('labels untitled notes and components the way the canvas does', () => {
  expect(toTableRow({ id: 'note', kind: 'note' }).label).toBe('Note')
  expect(toTableRow({ id: 'box', kind: 'component', label: '' }).label).toBe('Untitled component')
})
