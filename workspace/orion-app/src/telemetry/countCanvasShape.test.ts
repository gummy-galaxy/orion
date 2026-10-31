import { expect, test } from 'vitest'
import type { AppNode, Link } from '../model'
import { countCanvasShape } from './countCanvasShape'

const group = (id: string, parentId?: string): AppNode => ({
  id,
  type: 'cluster',
  parentId,
  position: { x: 0, y: 0 },
  data: { kind: 'cluster', label: id },
})

const card = (id: string, itemKind: 'step' | 'note' | 'component' = 'step', parentId?: string): AppNode => ({
  id,
  type: 'task',
  parentId,
  position: { x: 0, y: 0 },
  data: { kind: 'task', label: `Secret ${id}`, itemKind, status: 'todo' },
})

test('a canvas is counted by kind, with notes and components kept out of cards', () => {
  const nodes = [
    group('outer'),
    group('inner', 'outer'),
    card('a', 'step', 'inner'),
    card('b'),
    card('n', 'note'),
    card('c', 'component'),
  ]
  const links: Link[] = [
    { id: 'l1', from: 'a', to: 'b', kind: 'blocks' },
    { id: 'l2', from: 'b', to: 'n', kind: 'related' },
  ]
  const depth = new Map([
    ['outer', 0],
    ['inner', 1],
  ])
  const stickers = [{ id: 's', kind: '🎉', x: 0, y: 0, tilt: 0 }]

  expect(countCanvasShape(nodes, links, depth, stickers)).toEqual({
    card_count: 2,
    group_count: 2,
    nesting_depth: 2,
    link_count: 1,
    note_count: 1,
    media_count: 0,
    sticker_count: 1,
  })
})

test('an empty canvas counts nothing', () => {
  expect(countCanvasShape([], [], new Map(), [])).toEqual({
    card_count: 0,
    group_count: 0,
    nesting_depth: 0,
    link_count: 0,
    note_count: 0,
    media_count: 0,
    sticker_count: 0,
  })
})
