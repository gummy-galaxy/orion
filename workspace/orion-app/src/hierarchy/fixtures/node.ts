import type { AppNode } from '../../model'

/** A bare card or group, optionally inside `parentId`. */
export const node = (id: string, parentId?: string, type: 'task' | 'cluster' = 'task'): AppNode =>
  ({ id, type, parentId, position: { x: 0, y: 0 }, data: { label: id } }) as AppNode
