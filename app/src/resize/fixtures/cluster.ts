import type { AppNode, ClusterData } from '../../model'

export const cluster = (id: string, parentId: string | undefined, x: number, y: number, data: Partial<ClusterData> = {}): AppNode => ({
  id,
  type: 'cluster',
  parentId,
  position: { x, y },
  data: { kind: 'cluster', label: id, ...data },
})
