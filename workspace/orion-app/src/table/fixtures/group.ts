import type { ClusterNode } from '../../model'

/** A group labeled `label`, optionally inside `parentId`. */
export const group = (id: string, label: string, parentId?: string): ClusterNode => ({
  id,
  type: 'cluster',
  parentId,
  position: { x: 0, y: 0 },
  data: { kind: 'cluster', label },
})
