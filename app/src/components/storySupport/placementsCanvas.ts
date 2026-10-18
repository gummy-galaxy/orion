import { GROUP_HEADER_HEIGHT, GROUP_PADDING, type AppNode, type Link, type TaskData } from '../../model'
import type { Remote } from '../../persist'
import type { Placement } from '../../placements/types'

const card = (id: string, label: string, parentId: string, slot: number, extra: Partial<TaskData> = {}): AppNode => ({
  id,
  type: 'task',
  parentId,
  position: { x: GROUP_PADDING, y: GROUP_HEADER_HEIGHT + slot * 110 },
  data: { kind: 'task', label, itemKind: 'step', status: 'todo', ...extra },
})

const group = (id: string, label: string, x: number, y: number, blurb: string): AppNode => ({
  id,
  type: 'cluster',
  position: { x, y },
  data: { kind: 'cluster', label, blurb, arrange: 'custom' },
})

const link = (from: string, to: string): Link => ({ id: `${from}>${to}`, from, to, kind: 'blocks' })

/**
 * A small canvas for trying #122: "Sign-in flow" sits in Accounts and again in Launch, so its link to "Ship 1.0" draws
 * to the copy in Launch, and its link from "Session design" draws to the one in Accounts. "Release notes" appears in
 * Launch and Docs.
 */
export function placementsCanvas(): Remote {
  const nodes: AppNode[] = [
    group('accounts', 'Accounts', 0, 0, 'Where sign-in is built'),
    group('launch', 'Launch', 760, 0, 'What 1.0 waits on'),
    group('docs', 'Docs', 760, 520, 'What readers get'),
    card('session', 'Session design', 'accounts', 0, { status: 'done' }),
    card('sign-in', 'Sign-in flow', 'accounts', 1, { status: 'active', repo: 'vocksel/orion' }),
    card('ship', 'Ship 1.0', 'launch', 1, { itemKind: 'gate' }),
    card('notes', 'Release notes', 'launch', 2),
    card('guide', 'Getting started guide', 'docs', 0),
  ]
  const placements: Placement[] = [
    { id: 'sign-in-copy', node: 'sign-in', parentId: 'launch', position: { x: GROUP_PADDING, y: GROUP_HEADER_HEIGHT } },
    { id: 'notes-copy', node: 'notes', parentId: 'docs', position: { x: GROUP_PADDING, y: GROUP_HEADER_HEIGHT + 110 } },
  ]

  return {
    nodes,
    placements,
    links: [link('session', 'sign-in'), link('sign-in', 'ship'), link('notes', 'ship'), link('guide', 'notes')],
    revision: 1,
    settings: {},
  }
}
