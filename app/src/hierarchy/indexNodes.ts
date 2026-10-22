import type { AppNode } from '../model'
import type { NodeIndex } from './types'

export function indexNodes(nodes: AppNode[]): NodeIndex {
  // Built here rather than with `byId`, so model.ts can use this module without an import cycle.
  const nodeMap = new Map(nodes.map((node) => [node.id, node]))
  const children = new Map<string, AppNode[]>()
  const depth = new Map<string, number>()

  for (const node of nodes) {
    if (!node.parentId) continue

    const siblings = children.get(node.parentId)

    if (siblings) siblings.push(node)
    else children.set(node.parentId, [node])
  }

  // A parent id with no node behind it still counts as a level, as it does in `ancestors`.
  const depthOf = (id: string): number => {
    const known = depth.get(id)

    if (known !== undefined) return known

    const parentId = nodeMap.get(id)?.parentId
    const result = parentId ? 1 + (nodeMap.has(parentId) ? depthOf(parentId) : 0) : 0

    depth.set(id, result)

    return result
  }

  for (const node of nodes) depthOf(node.id)

  return { byId: nodeMap, children, depth }
}
