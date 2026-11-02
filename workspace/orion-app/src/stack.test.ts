import { describe, expect, it } from 'vitest'
import { stackNodes } from './stack'
import type { AppNode } from './model'

const task = (id: string, parentId?: string): AppNode => ({
  id,
  type: 'task',
  parentId,
  position: { x: 0, y: 0 },
  data: { kind: 'task', label: id, status: 'todo' },
})

const idsOf = (nodes: AppNode[]) => nodes.map((node) => node.id)

describe('stacking order', () => {
  it('moves a selected card one step later past the sibling above it', () => {
    const nodes = [task('a'), task('b'), task('c')]

    expect(idsOf(stackNodes(nodes, ['a'], 1))).toEqual(['b', 'a', 'c'])
  })

  it('moves a selected card one step earlier past the sibling below it', () => {
    const nodes = [task('a'), task('b'), task('c')]

    expect(idsOf(stackNodes(nodes, ['c'], -1))).toEqual(['a', 'c', 'b'])
  })

  it('moves a run of selected cards as a block past one unselected sibling', () => {
    const nodes = [task('a'), task('b'), task('c'), task('d')]

    expect(idsOf(stackNodes(nodes, ['a', 'b'], 1))).toEqual(['c', 'a', 'b', 'd'])
    expect(idsOf(stackNodes(nodes, ['c', 'd'], -1))).toEqual(['a', 'c', 'd', 'b'])
  })

  it('leaves a card that is already at the top or bottom where it is', () => {
    const nodes = [task('a'), task('b')]

    expect(stackNodes(nodes, ['b'], 1)).toBe(nodes)
    expect(stackNodes(nodes, ['a'], -1)).toBe(nodes)
  })

  it('only reorders siblings that share a parent', () => {
    const nodes = [task('g'), task('inside', 'g'), task('other'), task('inside-2', 'g')]

    expect(idsOf(stackNodes(nodes, ['inside'], 1))).toEqual(['g', 'inside-2', 'other', 'inside'])
  })
})
