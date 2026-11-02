import { describe, expect, it } from 'vitest'
import { emptyHistory, record, redo, undo } from './history'
import type { AppNode, Link } from './model'
import type { Saved } from './persist'

const makeNode = (id: string, x = 0, label = id): AppNode => ({
  id,
  type: 'task',
  position: { x, y: 0 },
  data: { kind: 'task', label, status: 'todo' },
})
const makeLink = (from: string, to: string): Link => ({ id: `${from}>${to}`, from, to, kind: 'blocks' })
const makeDoc = (nodes: AppNode[], links: Link[] = []): Saved => ({ nodes, links, stickers: [], stickerLoadout: [] })

describe('history', () => {
  it('undoes and redoes a move', () => {
    const before = makeDoc([makeNode('a', 0)])
    const after = makeDoc([makeNode('a', 100)])
    const undone = undo(record(emptyHistory(), { before, after }), after)!

    expect(undone.doc.nodes[0].position.x).toBe(0)
    expect(undone.history.undo).toEqual([])

    const redone = redo(undone.history, undone.doc)!

    expect(redone.doc.nodes[0].position.x).toBe(100)
    expect(redone.history.redo).toEqual([])
  })

  it('brings back a removed card and its links', () => {
    const before = makeDoc([makeNode('a'), makeNode('b')], [makeLink('a', 'b')])
    const after = makeDoc([makeNode('a')])
    const { doc } = undo(record(emptyHistory(), { before, after }), after)!

    expect(doc.nodes.map((node) => node.id).sort()).toEqual(['a', 'b'])
    expect(doc.links).toEqual([makeLink('a', 'b')])
  })

  it('keeps changes made elsewhere since the edit', () => {
    const before = makeDoc([makeNode('a', 0)])
    const after = makeDoc([makeNode('a', 100)])
    const current = makeDoc([makeNode('a', 100, 'renamed by the CLI'), makeNode('remote')])
    const { doc } = undo(record(emptyHistory(), { before, after }), current)!

    expect(doc.nodes.map((node) => node.id)).toEqual(['a', 'remote'])
    expect(doc.nodes[0]).toMatchObject({ position: { x: 0 }, data: { label: 'renamed by the CLI' } })
  })

  it("keeps another writer's value when it changed the same field", () => {
    const before = makeDoc([makeNode('a', 0)])
    const after = makeDoc([makeNode('a', 100)])
    const { doc } = undo(record(emptyHistory(), { before, after }), makeDoc([makeNode('a', 250)]))!

    expect(doc.nodes[0].position.x).toBe(250)
  })

  it('drops redo steps after a new edit and keeps a bounded history', () => {
    const one = makeDoc([makeNode('a', 1)])
    const two = makeDoc([makeNode('a', 2)])
    const undone = undo(record(emptyHistory(), { before: one, after: two }), two)!

    expect(record(undone.history, { before: one, after: two }).redo).toEqual([])

    let history = emptyHistory()

    for (let i = 0; i < 5; i++) history = record(history, { before: one, after: two }, 3)

    expect(history.undo).toHaveLength(3)
  })

  it('does nothing with an empty stack', () => {
    expect(undo(emptyHistory(), makeDoc([]))).toBeNull()
    expect(redo(emptyHistory(), makeDoc([]))).toBeNull()
  })
})
