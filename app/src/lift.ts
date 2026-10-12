import type { AppNode } from './model'

/**
 * The z-index a card gets while it is dragged. React Flow lifts selected nodes only when `elevateNodesOnSelect`
 * is on, and the canvas turns that off so bring forward and send backward show. Without a lift, a card dragged
 * over a neighbor later in the list would slide under it.
 */
export const DRAG_LIFT_Z = 1000

/** Lifts the dragged nodes. Returns the same array when none of them needs to change. */
export function liftNodes(nodes: AppNode[], ids: ReadonlySet<string>): AppNode[] {
  const needsLift = (node: AppNode) => ids.has(node.id) && node.zIndex !== DRAG_LIFT_Z

  if (!nodes.some(needsLift)) return nodes

  return nodes.map((node) => (needsLift(node) ? { ...node, zIndex: DRAG_LIFT_Z } : node))
}

/** Drops the lift from the dragged nodes once they are released. Other z-indexes are left alone. */
export function unliftNodes(nodes: AppNode[], ids: ReadonlySet<string>): AppNode[] {
  const isLifted = (node: AppNode) => ids.has(node.id) && node.zIndex === DRAG_LIFT_Z

  if (!nodes.some(isLifted)) return nodes

  return nodes.map((node) => (isLifted(node) ? { ...node, zIndex: undefined } : node))
}
