import { describe, expect, it } from 'vitest'
import { patchWork, sharedValue } from './batchEdit'
import type { AppNode, ItemKind, TaskData } from './model'

const card = (id: string, data: Partial<TaskData> = {}, itemKind: ItemKind = 'step'): AppNode => ({
  id,
  type: 'task',
  position: { x: 0, y: 0 },
  data: { kind: 'task', label: id, itemKind, status: 'todo', ...data },
})

const dataOf = (nodes: AppNode[], id: string) => nodes.find((node) => node.id === id)?.data as TaskData

describe('patch work', () => {
  it('sets the status on every selected work item and nothing else', () => {
    const nodes = [card('a'), card('b', { status: 'active' }), card('c')]
    const next = patchWork(nodes, new Set(['a', 'b']), { status: 'review' })

    expect(dataOf(next, 'a').status).toBe('review')
    expect(dataOf(next, 'b').status).toBe('review')
    expect(next[2]).toBe(nodes[2])
  })

  it('closes out cards it marks done, as a single edit does', () => {
    const next = patchWork([card('a'), card('b', { status: 'done' })], new Set(['a', 'b']), { status: 'done' })

    expect(dataOf(next, 'a').celebrate).toBe(false)
    expect(dataOf(next, 'b').celebrate).toBeUndefined()
  })

  it('sets and clears whose move it is', () => {
    const nodes = [card('a'), card('b', { who: 'ci' })]

    expect(patchWork(nodes, new Set(['a', 'b']), { who: 'you' }).map((node) => (node.data as TaskData).who)).toEqual(['you', 'you'])
    expect(patchWork(nodes, new Set(['a', 'b']), { who: undefined }).map((node) => (node.data as TaskData).who)).toEqual([undefined, undefined])
  })

  it('leaves notes, components, and groups alone', () => {
    const group: AppNode = { id: 'g', type: 'cluster', position: { x: 0, y: 0 }, data: { kind: 'cluster', label: 'g' } }
    const nodes = [card('note', {}, 'note'), card('part', {}, 'component'), group]

    expect(patchWork(nodes, new Set(['note', 'part', 'g']), { status: 'done' })).toBe(nodes)
  })

  it('returns the same nodes when every item already matches', () => {
    const nodes = [card('a', { status: 'done', who: 'you' }), card('b', { status: 'done', who: 'you' })]

    expect(patchWork(nodes, new Set(['a', 'b']), { status: 'done' })).toBe(nodes)
    expect(patchWork(nodes, new Set(['a', 'b']), { who: 'you' })).toBe(nodes)
  })
})

describe('shared value', () => {
  it('names the value every item shares', () => {
    expect(sharedValue(['todo', 'todo'])).toBe('todo')
    expect(sharedValue([undefined, undefined])).toBeUndefined()
  })

  it('says mixed when they differ', () => {
    expect(sharedValue(['todo', 'done'])).toBe('mixed')
    expect(sharedValue(['you', undefined])).toBe('mixed')
  })
})
