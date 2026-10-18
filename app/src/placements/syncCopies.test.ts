import { expect, test } from 'vitest'
import type { AppNode, TaskData } from '../model'
import { expandPlacements } from './expandPlacements'
import { foldPlacements } from './foldPlacements'
import { syncCopies } from './syncCopies'

const card = (id: string, label: string, parentId?: string): AppNode => ({
  id,
  type: 'task',
  position: { x: 0, y: 0 },
  ...(parentId ? { parentId } : {}),
  data: { kind: 'task', label, itemKind: 'step', status: 'todo' },
})

const nodes = expandPlacements([card('login', 'Login')], [{ id: 'login-copy', node: 'login', parentId: 'release', position: { x: 5, y: 5 } }])

test('a copy draws the card in its placement', () => {
  expect(nodes[1]).toMatchObject({ id: 'login-copy', parentId: 'release', data: { label: 'Login', copyOf: 'login' } })
})

test('editing a copy edits the card and every other copy', () => {
  const edited = nodes.map((node) => (node.id === 'login-copy' ? { ...node, data: { ...node.data, label: 'Sign in' } } : node)) as AppNode[]
  const synced = syncCopies(nodes, edited)

  expect((synced[0].data as TaskData).label).toBe('Sign in')
  expect((synced[0].data as TaskData).copyOf).toBeUndefined()
  expect((synced[1].data as TaskData).copyOf).toBe('login')
})

test('copies fold back into placements', () => {
  const folded = foldPlacements(nodes)

  expect(folded.nodes.map((node) => node.id)).toEqual(['login'])
  expect(folded.placements).toEqual([{ id: 'login-copy', node: 'login', parentId: 'release', position: { x: 5, y: 5 } }])
})
