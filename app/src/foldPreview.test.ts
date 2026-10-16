import { describe, expect, it } from 'vitest'
import { FOLD_PREVIEW_LIMIT, foldPreviews, sameFoldPreview, type FoldPreviewItem } from './foldPreview'
import { byId, type AppNode, type ViewStatus } from './model'

const CARD_SIZE = { width: 216, height: 100 }

const group = (id: string, x: number, y: number, parentId?: string): AppNode =>
  ({
    id,
    type: 'cluster',
    parentId,
    position: { x, y },
    width: 600,
    height: 400,
    data: { kind: 'cluster', label: id },
  }) as AppNode

const card = (id: string, x: number, y: number, parentId?: string): AppNode =>
  ({ id, type: 'task', parentId, position: { x, y }, data: { kind: 'task', label: id, status: 'todo' } }) as AppNode

const image = (id: string, x: number, y: number, parentId?: string): AppNode =>
  ({ id, type: 'image', parentId, position: { x, y }, width: 120, height: 90, data: { kind: 'image', label: id } }) as AppNode

const build = (nodes: AppNode[], folded: string[], status: Record<string, ViewStatus> = {}) =>
  foldPreviews(nodes, byId(nodes), new Set(folded), CARD_SIZE, new Map(Object.entries(status)))

describe('foldPreviews', () => {
  it('has nothing to draw when no group is folded', () => {
    const nodes = [group('a', 0, 0), card('task', 10, 10, 'a')]

    expect(build(nodes, []).size).toBe(0)
  })

  it('lists what is inside a folded group, positioned from the group corner', () => {
    const nodes = [group('a', 100, 200), card('one', 30, 40, 'a'), image('pic', 300, 60, 'a')]
    const previews = build(nodes, ['a'])
    const items = previews.get('a')!

    expect(items.map((item) => item.id)).toEqual(['one', 'pic'])
    expect(items[0]).toMatchObject({ kind: 'card', x: 30, y: 40, width: 216, height: 100, depth: 0, status: 'ready' })
    expect(items[1]).toMatchObject({ kind: 'image', x: 300, y: 60, width: 120, height: 90, status: null })
  })

  it('reads positions through nested parents, and counts the groups between an item and the folded one', () => {
    const nodes = [group('outer', 0, 0), group('inner', 50, 50, 'outer'), card('deep', 20, 20, 'inner')]
    const items = build(nodes, ['outer']).get('outer')!

    expect(items).toHaveLength(2)
    expect(items.find((item) => item.id === 'inner')).toMatchObject({ kind: 'group', x: 50, y: 50, depth: 0 })
    expect(items.find((item) => item.id === 'deep')).toMatchObject({ kind: 'card', x: 70, y: 70, depth: 1 })
  })

  it('gives an item only to the outermost folded group above it', () => {
    const nodes = [group('outer', 0, 0), group('inner', 50, 50, 'outer'), card('deep', 20, 20, 'inner')]
    const previews = build(nodes, ['outer', 'inner'])

    expect(previews.has('inner')).toBe(false)
    expect(previews.get('outer')!.map((item) => item.id)).toEqual(['inner', 'deep'])
  })

  it('previews each folded group on its own when they are side by side', () => {
    const nodes = [group('left', 0, 0), group('right', 800, 0), card('a', 10, 10, 'left'), card('b', 810, 10, 'right')]
    const previews = build(nodes, ['left', 'right'])

    expect(previews.get('left')!.map((item) => item.id)).toEqual(['a'])
    expect(previews.get('right')!.map((item) => item.id)).toEqual(['b'])
  })

  it('colors each card by its status, and defaults to ready', () => {
    const nodes = [group('a', 0, 0), card('blocked', 10, 10, 'a'), card('plain', 10, 130, 'a')]
    const items = build(nodes, ['a'], { blocked: 'blocked' }).get('a')!

    expect(items.find((item) => item.id === 'blocked')!.status).toBe('blocked')
    expect(items.find((item) => item.id === 'plain')!.status).toBe('ready')
  })

  it('draws nearest items first and caps the count per group', () => {
    const many = Array.from({ length: FOLD_PREVIEW_LIMIT + 20 }, (_, index) => card(`deep-${index}`, index, index, 'inner'))
    const nodes = [group('a', 0, 0), card('near', 5, 5, 'a'), group('inner', 0, 0, 'a'), ...many]
    const items = build(nodes, ['a']).get('a')!

    expect(items).toHaveLength(FOLD_PREVIEW_LIMIT)
    expect(items[0].id).toBe('near')
    expect(items[1].id).toBe('inner')
    expect(items.every((item: FoldPreviewItem) => item.depth <= 1)).toBe(true)
  })

  it('ignores nodes whose parent is not on the canvas', () => {
    const nodes = [group('a', 0, 0), card('orphan', 10, 10, 'missing')]

    expect(build(nodes, ['a']).has('a')).toBe(false)
  })
})

describe('sameFoldPreview', () => {
  const item: FoldPreviewItem = { id: 'one', kind: 'card', status: 'ready', x: 1, y: 2, width: 3, height: 4, depth: 0 }

  it('matches identical previews and treats a missing one as different', () => {
    expect(sameFoldPreview([item], [{ ...item }])).toBe(true)
    expect(sameFoldPreview(undefined, undefined)).toBe(true)
    expect(sameFoldPreview(undefined, [item])).toBe(false)
  })

  it('notices a move, a status change, a new depth, or a new item', () => {
    expect(sameFoldPreview([item], [{ ...item, x: 9 }])).toBe(false)
    expect(sameFoldPreview([item], [{ ...item, status: 'done' }])).toBe(false)
    expect(sameFoldPreview([item], [{ ...item, depth: 1 }])).toBe(false)
    expect(sameFoldPreview([item], [item, { ...item, id: 'two' }])).toBe(false)
  })
})
