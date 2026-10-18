import { byId, type AppNode } from '../../model'

/** A node's box as the canvas holds it, after `normalize` has sized it. */
export const boxOf = (nodes: AppNode[], id: string) => {
  const node = byId(nodes).get(id)!

  return { ...node.position, width: node.width!, height: node.height! }
}
