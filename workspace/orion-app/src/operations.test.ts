import { describe, expect, it } from 'vitest'
import { diffOperations, type OperationDoc, type StoredNode } from './operations'
import type { Link } from './model'

const task = (id: string, parentId?: string, x = 0, y = 0): StoredNode => ({
  id,
  type: 'task',
  position: { x, y },
  parentId,
  data: { kind: 'task', label: id, status: 'todo' },
})

const group = (id: string, parentId?: string, x = 0, y = 0): StoredNode => ({
  id,
  type: 'cluster',
  position: { x, y },
  parentId,
  width: 400,
  height: 300,
  data: { kind: 'cluster', label: id },
})

const doc = (nodes: StoredNode[], links: Link[] = []): OperationDoc => ({
  nodes,
  links,
  stickers: [],
  stickerLoadout: [],
})

const link = (from: string, to: string, kind: Link['kind'] = 'blocks'): Link => ({
  id: `${from}>${to}`,
  from,
  to,
  kind,
})

describe('diffOperations', () => {
  it('sends nothing when the canvas matches what was saved', () => {
    const saved = doc([task('a'), group('g'), task('b', 'g')], [link('a', 'b')])

    expect(diffOperations(saved, structuredClone(saved))).toEqual([])
  })

  it('ignores key order inside data', () => {
    const base = doc([task('a')])
    const current = doc([{ ...task('a'), data: { status: 'todo', label: 'a', kind: 'task' } }])

    expect(diffOperations(base, current)).toEqual([])
  })

  it("sends a card's changed fields as setFields, and closes out a card it finished", () => {
    const base = doc([task('a'), task('b')])
    const current = doc([
      { ...task('a'), data: { ...task('a').data, status: 'done' } },
      { ...task('b'), data: { ...task('b').data, label: 'Renamed' } },
    ])

    expect(diffOperations(base, current)).toEqual([
      { op: 'setFields', id: 'a', fields: { status: 'done' } },
      { op: 'closeOut', id: 'a' },
      { op: 'setFields', id: 'b', fields: { label: 'Renamed' } },
    ])
  })

  it("sends a group's changed data whole as setData", () => {
    const base = doc([group('g')])
    const current = doc([{ ...group('g'), data: { kind: 'cluster', label: 'Renamed' } }])

    expect(diffOperations(base, current)).toEqual([{ op: 'setData', id: 'g', data: current.nodes[0].data }])
  })

  it('sends a moved item as place, and a resized group as resize, clearing its size back at the default', () => {
    const base = doc([task('a', undefined, 0, 0), group('g')])
    const moved = doc([{ ...task('a', undefined, 30, 40) }, { ...group('g'), width: undefined, height: undefined }])

    expect(diffOperations(base, moved)).toEqual([
      { op: 'resize', id: 'g', clear: true },
      { op: 'place', id: 'a', x: 30, y: 40 },
    ])
  })

  it('adds a new card, with the group it goes in already in place', () => {
    const base = doc([group('g')])
    const current = doc([group('g'), task('n', 'g', 16, 32)])

    expect(diffOperations(base, current)).toEqual([
      {
        op: 'addCard',
        id: 'n',
        x: 16,
        y: 32,
        group: 'g',
        width: undefined,
        height: undefined,
        data: current.nodes[1].data,
      },
    ])
  })

  it('adds a new note as addNote, and an image as addImage', () => {
    const note = { ...task('note-1', undefined, 4, 8), data: { kind: 'task', label: '', type: 'note', status: 'todo' } }
    const image = {
      id: 'img',
      type: 'image',
      position: { x: 0, y: 0 },
      data: { kind: 'image', label: 'Photo', asset: 'a.png' },
    }
    const ops = diffOperations(doc([]), doc([note, image]))

    expect(ops.map((op) => op.op)).toEqual(['addNote', 'addImage'])
  })

  it('creates parents before the items inside them', () => {
    const base = doc([])
    const current = doc([task('inner', 'outer'), group('outer')])
    const ops = diffOperations(base, current)

    expect(ops.map((op) => op.id)).toEqual(['outer', 'inner'])
  })

  it('groups existing items with a group op, then places the group and its items', () => {
    const base = doc([task('a'), task('b')])
    const current = doc([group('batch'), task('a', 'batch', 16, 32), task('b', 'batch', 16, 140)])
    const ops = diffOperations(base, current)

    expect(ops.find((op) => op.op === 'group')).toEqual({ op: 'group', id: 'batch', label: 'batch', items: ['a', 'b'] })
    expect(ops.findIndex((op) => op.op === 'group')).toBeLessThan(
      ops.findIndex((op) => op.op === 'place' && op.id === 'a'),
    )
    expect(ops).toContainEqual({ op: 'place', id: 'batch', x: 0, y: 0 })
  })

  it('moves items into a shared parent before grouping them', () => {
    const base = doc([group('p1'), task('a', 'p1'), task('b')])
    const current = doc([group('p1'), group('batch', 'p1'), task('a', 'batch'), task('b', 'batch')])
    const ops = diffOperations(base, current)

    expect(ops).toContainEqual({ op: 'move', id: 'b', group: 'p1' })
    expect(ops.findIndex((op) => op.op === 'move' && op.id === 'b')).toBeLessThan(
      ops.findIndex((op) => op.op === 'group'),
    )
  })

  it('dissolves a group whose items all moved up as ungroup, without moving them again', () => {
    const base = doc([group('g'), task('a', 'g'), task('b', 'g')])
    const current = doc([task('a', undefined, 10, 20), task('b', undefined, 10, 120)])
    const ops = diffOperations(base, current)

    expect(ops.filter((op) => op.op === 'ungroup')).toEqual([{ op: 'ungroup', id: 'g' }])
    expect(ops.some((op) => op.op === 'move')).toBe(false)
    expect(ops).toContainEqual({ op: 'place', id: 'a', x: 10, y: 20 })
  })

  it('moves an item out of a group with move, then places it', () => {
    const base = doc([group('g'), task('a', 'g')])
    const current = doc([group('g'), task('a', undefined, 50, 60)])

    expect(diffOperations(base, current)).toEqual([
      { op: 'move', id: 'a' },
      { op: 'place', id: 'a', x: 50, y: 60 },
    ])
  })

  it('moves an item into a group before the item leaving that group empties it', () => {
    const base = doc([group('g'), task('x', 'g'), task('y')])
    const current = doc([group('g'), task('x'), task('y', 'g')])
    const ops = diffOperations(base, current)

    expect(ops.findIndex((op) => op.op === 'move' && op.id === 'y')).toBeLessThan(
      ops.findIndex((op) => op.op === 'move' && op.id === 'x'),
    )
  })

  it('removes a card and leaves the group it was in to the server', () => {
    const base = doc([group('g'), task('a', 'g')])
    const current = doc([group('g')])

    expect(diffOperations(base, current)).toEqual([{ op: 'remove', id: 'a' }])
  })

  it('removes a group with everything in it as removes, without a removeGroup for the group itself', () => {
    const base = doc([group('g'), task('a', 'g'), task('b', 'g')])
    const current = doc([])

    expect(diffOperations(base, current)).toEqual([
      { op: 'remove', id: 'a' },
      { op: 'remove', id: 'b' },
    ])
  })

  it('removes an empty group with removeGroup', () => {
    const base = doc([group('g')])
    const current = doc([])

    expect(diffOperations(base, current)).toEqual([{ op: 'removeGroup', id: 'g' }])
  })

  it('adds, removes, and flips links', () => {
    const base = doc([task('a'), task('b'), task('c')], [link('a', 'b'), link('b', 'c')])
    const current = doc([task('a'), task('b'), task('c')], [link('a', 'b', 'related'), link('a', 'c')])
    const ops = diffOperations(base, current)

    expect(ops).toContainEqual({ op: 'link', from: 'a', to: 'b', kind: 'related' })
    expect(ops).toContainEqual({ op: 'link', from: 'a', to: 'c', kind: 'blocks' })
    expect(ops).toContainEqual({ op: 'unlink', from: 'b', to: 'c' })
  })

  it('sends a link again when its label changes, with an empty label to clear one', () => {
    const base = doc([task('a'), task('b'), task('c')], [link('a', 'b'), { ...link('b', 'c'), label: 'HTTP' }])
    const current = doc([task('a'), task('b'), task('c')], [{ ...link('a', 'b'), label: 'SQL' }, link('b', 'c')])
    const ops = diffOperations(base, current)

    expect(ops).toContainEqual({ op: 'link', from: 'a', to: 'b', kind: 'blocks', label: 'SQL' })
    expect(ops).toContainEqual({ op: 'link', from: 'b', to: 'c', kind: 'blocks', label: '' })
  })

  it('leaves links that touch a removed card to the removal', () => {
    const base = doc([task('a'), task('b')], [link('a', 'b')])
    const current = doc([task('a')])

    expect(diffOperations(base, current)).toEqual([{ op: 'remove', id: 'b' }])
  })

  it('sends sticker lists whole when they change', () => {
    const base = doc([task('a')])
    const sticker = { id: 's1', kind: '🎉', x: 1, y: 2, tilt: 0 }
    const current = { ...doc([task('a')]), stickers: [sticker] }

    expect(diffOperations(base, current)).toEqual([{ op: 'setStickers', stickers: [sticker] }])
  })

  it('sends a loadout change as setStickerLoadout', () => {
    const base = doc([task('a')])
    const current = { ...doc([task('a')]), stickerLoadout: ['🎉', null] }

    expect(diffOperations(base, current)).toEqual([{ op: 'setStickerLoadout', stickerLoadout: ['🎉', null] }])
  })

  it('orders edits so that creates come before the links that use them', () => {
    const base = doc([task('a')])
    const current = doc([task('a'), task('n')], [link('a', 'n')])
    const ops = diffOperations(base, current)

    expect(ops.map((op) => op.op)).toEqual(['addCard', 'link'])
  })
})
