import type { AppNode } from '../model'

/**
 * Whether two node lists hold the same cards for the table: the same nodes in the same order, each with the same data
 * and parent. Dragging or selecting a node replaces the node but keeps its data, so those compare equal.
 */
export function isSameTableNodes(a: AppNode[], b: AppNode[]): boolean {
  return a.length === b.length && a.every((node, i) => node.id === b[i].id && node.data === b[i].data && node.parentId === b[i].parentId)
}
