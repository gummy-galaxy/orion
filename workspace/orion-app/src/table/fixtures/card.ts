import type { ItemKind, TaskNode } from '../../model'

/** A card labeled `label`, optionally inside `parentId`. */
export const card = (id: string, label: string, parentId?: string, itemKind: ItemKind = 'step', refs?: TaskNode['data']['refs']): TaskNode => ({
  id,
  type: 'task',
  parentId,
  position: { x: 0, y: 0 },
  data: { kind: 'task', label, itemKind, status: 'todo', refs },
})
