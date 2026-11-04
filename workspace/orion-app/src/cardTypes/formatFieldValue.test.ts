import { expect, test } from 'vitest'
import { FIGMA_FRAME } from './fixtures/figmaFrame'
import { formatFieldValue } from './formatFieldValue'

const field = (name: string) => FIGMA_FRAME.fields.find((candidate) => candidate.name === name)!

test('a choice shows its label, a link its host, and a yes or no for a flag', () => {
  expect(formatFieldValue(field('stage'), 'review')).toBe('In review')
  expect(formatFieldValue(field('file'), 'https://www.figma.com/file/abc')).toBe('www.figma.com')
  expect(formatFieldValue(field('shared'), false)).toBe('No')
  expect(formatFieldValue(field('screens'), 4)).toBe('4')
})

test('a date shows in the reader’s words, and an empty value shows nothing', () => {
  expect(formatFieldValue(field('due'), '2026-11-02')).toBe(
    new Date(2026, 10, 2).toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
  )
  expect(formatFieldValue(field('stage'), undefined)).toBeUndefined()
  expect(formatFieldValue(field('file'), '')).toBeUndefined()
})
