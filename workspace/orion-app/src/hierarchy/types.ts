import type { AppNode } from '../model'

/** Lookups built once per node list, so finding a node's parent, children, or depth never rescans the list. */
export type NodeIndex = {
  byId: Map<string, AppNode>
  /** Each parent's direct children, in node order. A node with nothing inside has no entry. */
  children: Map<string, AppNode[]>
  /** How many parents each node sits inside, 0 at the top level. */
  depth: Map<string, number>
}
