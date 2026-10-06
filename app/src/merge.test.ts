import { describe, expect, it } from 'vitest'
import { mergeDocs } from './merge'
import type { AppNode, Link } from './model'
import type { Saved } from './persist'

const makeNode = (id: string, label = id): AppNode => ({
  id,
  type: 'task',
  position: { x: 0, y: 0 },
  data: { kind: 'task', label, itemKind: 'step', status: 'todo' },
})
const makeLink = (id: string, from: string, to: string): Link => ({ id, from, to, kind: 'blocks' })
const makeDoc = (nodes: AppNode[], links: Link[] = []): Saved => ({ nodes, links })

describe('mergeDocs', () => {
  it('keeps nodes added on either side', () => {
    const merged = mergeDocs(makeDoc([makeNode('a')]), makeDoc([makeNode('a'), makeNode('local')]), makeDoc([makeNode('a'), makeNode('remote')]))
    expect(merged.nodes.map((n) => n.id)).toEqual(['a', 'remote', 'local'])
    expect(merged.conflicts).toEqual([])
  })

  it('deletes a node when the other side left it unchanged', () => {
    const base = makeDoc([makeNode('a'), makeNode('b')])
    expect(mergeDocs(base, makeDoc([makeNode('b')]), base).nodes.map((n) => n.id)).toEqual(['b'])
    expect(mergeDocs(base, base, makeDoc([makeNode('b')])).nodes.map((n) => n.id)).toEqual(['b'])
  })

  it('keeps an edit against a deletion in either direction', () => {
    const base = makeDoc([makeNode('a')])
    const edited = makeDoc([makeNode('a', 'edited')])
    expect(mergeDocs(base, edited, makeDoc([])).nodes[0].data.label).toBe('edited')
    expect(mergeDocs(base, makeDoc([]), edited).nodes[0].data.label).toBe('edited')
  })

  it('merges independent node fields and data keys', () => {
    const original = makeNode('a')
    const local = { ...original, position: { x: 10, y: 20 }, width: 300, data: { ...original.data, label: 'local' } } as AppNode
    const remote = { ...original, parentId: 'group', height: 200, data: { ...original.data, status: 'active' } } as AppNode
    const merged = mergeDocs(makeDoc([original]), makeDoc([local]), makeDoc([remote]))
    expect(merged.nodes[0]).toMatchObject({
      position: { x: 10, y: 20 },
      parentId: 'group',
      width: 300,
      height: 200,
      data: { label: 'local', status: 'active' },
    })
    expect(merged.conflicts).toEqual([])
  })

  it('reports each conflicting field and keeps the local value', () => {
    const original = makeNode('a')
    const local = { ...original, position: { x: 1, y: 0 }, data: { ...original.data, label: 'ours', note: 'local' } } as AppNode
    const remote = { ...original, position: { x: 2, y: 0 }, data: { ...original.data, label: 'theirs', note: 'remote' } } as AppNode
    const merged = mergeDocs(makeDoc([original]), makeDoc([local]), makeDoc([remote]))
    expect(merged.nodes[0]).toMatchObject({ position: { x: 1, y: 0 }, data: { label: 'ours', note: 'local' } })
    expect(merged.conflicts).toEqual([
      { id: 'a', field: 'position' },
      { id: 'a', field: 'data.label' },
      { id: 'a', field: 'data.note' },
    ])
  })

  it('merges data key removal and reports removal against a concurrent edit', () => {
    const original = { ...makeNode('a'), data: { ...makeNode('a').data, note: 'before' } } as AppNode
    const local = { ...original, data: { kind: 'task', label: 'a', itemKind: 'step', status: 'todo' } } as AppNode
    const remote = { ...original, data: { ...original.data, label: 'remote' } } as AppNode
    const independent = mergeDocs(makeDoc([original]), makeDoc([local]), makeDoc([remote]))
    expect(independent.nodes[0].data).toMatchObject({ label: 'remote' })
    expect('note' in independent.nodes[0].data).toBe(false)
    expect(independent.conflicts).toEqual([])

    const competing = mergeDocs(
      makeDoc([original]),
      makeDoc([local]),
      makeDoc([{ ...original, data: { ...original.data, note: 'theirs' } } as AppNode]),
    )
    expect('note' in competing.nodes[0].data).toBe(false)
    expect(competing.conflicts).toEqual([{ id: 'a', field: 'data.note' }])
  })

  it('compares values structurally, including property order', () => {
    const original = makeNode('a')
    const local = { ...original, position: { x: 0, y: 0 }, data: { ...original.data, github: { state: 'OPEN', draft: false } } } as AppNode
    const remote = { ...original, position: { y: 0, x: 0 }, data: { ...original.data, github: { draft: false, state: 'OPEN' } } } as AppNode
    expect(mergeDocs(makeDoc([original]), makeDoc([local]), makeDoc([remote])).conflicts).toEqual([])
  })

  it('merges links by id and removes links with missing endpoints', () => {
    const nodes = [makeNode('a'), makeNode('b'), makeNode('c')]
    const base = makeDoc(nodes, [makeLink('old', 'a', 'b'), makeLink('edited', 'a', 'b'), makeLink('orphan', 'a', 'c')])
    const local = makeDoc(nodes.slice(0, 2), [{ ...makeLink('edited', 'a', 'b'), kind: 'related' }, makeLink('local', 'a', 'b')])
    const remote = makeDoc(nodes, [
      makeLink('old', 'a', 'b'),
      makeLink('edited', 'a', 'b'),
      makeLink('orphan', 'a', 'c'),
      makeLink('remote', 'b', 'a'),
    ])
    const merged = mergeDocs(base, local, remote)
    expect(merged.links.map((l) => l.id)).toEqual(['edited', 'remote', 'local'])
    expect(merged.conflicts).toEqual([])
  })

  it('keeps an edited link against deletion and resolves concurrent link edits locally', () => {
    const nodes = [makeNode('a'), makeNode('b'), makeNode('c')]
    const base = makeDoc(nodes, [makeLink('edge', 'a', 'b')])
    const changed = makeDoc(nodes, [{ ...makeLink('edge', 'a', 'b'), kind: 'related' }])
    expect(mergeDocs(base, changed, makeDoc(nodes)).links[0].kind).toBe('related')
    expect(mergeDocs(base, makeDoc(nodes), changed).links[0].kind).toBe('related')
    const merged = mergeDocs(base, makeDoc(nodes, [makeLink('edge', 'b', 'b')]), makeDoc(nodes, [makeLink('edge', 'c', 'b')]))
    expect(merged.links[0].from).toBe('b')
    expect(merged.conflicts).toEqual([{ id: 'edge', field: 'from' }])
  })

  it('keeps stacked-link provenance alongside an independent link edit', () => {
    const nodes = [makeNode('a'), makeNode('b')]
    const original = makeLink('edge', 'a', 'b')
    const merged = mergeDocs(
      makeDoc(nodes, [original]),
      makeDoc(nodes, [{ ...original, origin: 'stack' }]),
      makeDoc(nodes, [{ ...original, kind: 'related' }]),
    )
    expect(merged.links).toEqual([{ ...original, kind: 'related', origin: 'stack' }])
    expect(merged.conflicts).toEqual([])
  })
})
