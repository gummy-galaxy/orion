import type { AppNode } from '../../model'

export const task = (id: string, parentId: string | undefined, x: number, y: number): AppNode => ({
  id,
  type: 'task',
  parentId,
  position: { x, y },
  data: { kind: 'task', label: id, itemKind: 'step', status: 'todo' },
})
