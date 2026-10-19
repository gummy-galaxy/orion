import { GAP } from '../../layout'
import { GROUP_HEADER_HEIGHT, GROUP_PADDING, TASK_HEIGHT, TASK_WIDTH, type AppNode, type Link, type TaskData } from '../../model'
import type { Remote } from '../../persist'
import type { Placement } from '../../placements/types'

/** Where a card sits in its group's grid, in the stored form that each skin scales to its own card size. */
const slot = (column: number, row: number) => ({
  x: GROUP_PADDING + column * (TASK_WIDTH + GAP.inner.x),
  y: GROUP_HEADER_HEIGHT + row * (TASK_HEIGHT + GAP.inner.y),
})

const card = (id: string, label: string, parentId: string, column: number, row: number, extra: Partial<TaskData> = {}): AppNode => ({
  id,
  type: 'task',
  parentId,
  position: slot(column, row),
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
    group('launch', 'Launch', 380, 0, 'What 1.0 waits on'),
    group('docs', 'Docs', 1020, 0, 'What readers get'),
    card('session', 'Session design', 'accounts', 0, 0, { status: 'done' }),
    card('sign-in', 'Sign-in flow', 'accounts', 0, 1, { status: 'active', repo: 'vocksel/orion' }),
    card('ship', 'Ship 1.0', 'launch', 1, 0, { itemKind: 'gate' }),
    card('notes', 'Release notes', 'launch', 1, 1),
    card('guide', 'Getting started guide', 'docs', 0, 0),
  ]
  const placements: Placement[] = [
    { id: 'sign-in-copy', node: 'sign-in', parentId: 'launch', position: slot(0, 0) },
    { id: 'notes-copy', node: 'notes', parentId: 'docs', position: slot(0, 1) },
  ]

  return {
    nodes,
    placements,
    links: [link('session', 'sign-in'), link('sign-in', 'ship'), link('notes', 'ship'), link('guide', 'notes')],
    revision: 1,
    settings: {},
  }
}
