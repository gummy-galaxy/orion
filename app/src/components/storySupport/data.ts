import { deriveWork, type SourceRef } from '../../derive'
import type { AppNode, ClusterNode, GhostNode, Link, TaskNode } from '../../model'

export const task: TaskNode = {
  id: 'task',
  type: 'task',
  position: { x: 80, y: 150 },
  data: {
    kind: 'task',
    itemKind: 'pr',
    label: 'Make the canvas welcoming',
    status: 'active',
    repo: 'vocksel/orion',
    who: 'you',
    refs: [{ source: 'github', kind: 'pull', key: 'vocksel/orion#127', url: 'https://github.com/vocksel/orion/pull/127' }],
  },
}

export const blocker: TaskNode = {
  id: 'blocker',
  type: 'task',
  position: { x: 400, y: 150 },
  data: { kind: 'task', itemKind: 'step', label: 'Review the component split', status: 'todo' },
}

export const note: TaskNode = {
  id: 'note',
  type: 'task',
  position: { x: 80, y: 260 },
  data: { kind: 'task', itemKind: 'note', label: 'Keep the intent visible', status: 'todo' },
}

export const group: ClusterNode = {
  id: 'group',
  type: 'cluster',
  position: { x: 50, y: 70 },
  width: 450,
  height: 260,
  data: { kind: 'cluster', label: 'Canvas', blurb: 'Work on the visual workspace' },
}

export const ghost: GhostNode = {
  id: 'ghost',
  type: 'ghost',
  position: { x: 50, y: 170 },
  data: { kind: 'ghost', taskId: 'task', label: 'Review the component split', where: 'Canvas', status: 'review', side: 'in' },
}

export const links: Link[] = [{ id: 'link', from: 'task', to: 'blocker', kind: 'blocks' }]
export const work = deriveWork([task, blocker, note, group], links)
export const nodeMap = new Map<string, AppNode>([task, blocker, note, group].map((node) => [node.id, node]))
export const source: SourceRef = { domain: 'github.com', label: 'vocksel/orion#127', href: 'https://github.com/vocksel/orion/pull/127' }
