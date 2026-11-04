import { describe, expect, it } from 'vitest'
import { TOP_LEVEL_SELECT_LIMIT, selectAllIds, selectNodes } from './selectAll'
import type { AppNode } from './model'

const task = (id: string, parentId?: string, selected?: boolean): AppNode => ({
  id,
  type: 'task',
  parentId,
  selected,
  position: { x: 0, y: 0 },
  data: { kind: 'task', label: id, status: 'todo' },
})

const many = (count: number, parentId?: string) =>
  Array.from({ length: count }, (_, i) => task(`${parentId ?? 'top'}-${i}`, parentId))

describe('select all', () => {
  it('takes the items directly inside the open group', () => {
    const nodes = [task('g'), task('a', 'g'), task('b', 'g'), task('nested', 'a'), task('other')]

    expect(selectAllIds(nodes, 'g', new Set())).toEqual(['a', 'b'])
  })

  it('takes the top-level items when no group is open', () => {
    const nodes = [task('g'), task('a', 'g'), task('other')]

    expect(selectAllIds(nodes, null, new Set())).toEqual(['g', 'other'])
  })

  it('leaves out hidden items', () => {
    const nodes = [task('g'), task('a', 'g'), task('b', 'g')]

    expect(selectAllIds(nodes, 'g', new Set(['b']))).toEqual(['a'])
  })

  it('gives up at the top level past the limit', () => {
    expect(selectAllIds(many(TOP_LEVEL_SELECT_LIMIT), null, new Set())).toHaveLength(TOP_LEVEL_SELECT_LIMIT)
    expect(selectAllIds(many(TOP_LEVEL_SELECT_LIMIT + 1), null, new Set())).toBeNull()
  })

  it('has no limit inside a group', () => {
    const nodes = [task('g'), ...many(TOP_LEVEL_SELECT_LIMIT * 2, 'g')]

    expect(selectAllIds(nodes, 'g', new Set())).toHaveLength(TOP_LEVEL_SELECT_LIMIT * 2)
  })

  it('selects exactly the ids given and clears the rest', () => {
    const nodes = [task('a'), task('b', undefined, true), task('c')]
    const next = selectNodes(nodes, ['a', 'c'])

    expect(next.map((node) => Boolean(node.selected))).toEqual([true, false, true])
  })

  it('returns the same array when the selection already matches', () => {
    const nodes = [task('a', undefined, true), task('b')]

    expect(selectNodes(nodes, ['a'])).toBe(nodes)
  })
})
