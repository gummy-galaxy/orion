import type { AppNode } from './model'

/** Selecting many cards at once is slow, so select all at the top level stops past this many. */
export const TOP_LEVEL_SELECT_LIMIT = 50

/**
 * The visible items directly inside the open group, or at the top level when `root` is null. At the
 * top level, returns null once there are more than `TOP_LEVEL_SELECT_LIMIT`. A group has no limit.
 */
export function selectAllIds(nodes: AppNode[], root: string | null, hidden: ReadonlySet<string>): string[] | null {
  const ids: string[] = []

  for (const node of nodes) {
    if ((node.parentId ?? null) !== root || hidden.has(node.id)) continue

    ids.push(node.id)

    if (!root && ids.length > TOP_LEVEL_SELECT_LIMIT) return null
  }

  return ids
}

/** Selects exactly `ids`, keeping each node that doesn't change. Returns the same array when nothing does. */
export function selectNodes(nodes: AppNode[], ids: string[]): AppNode[] {
  const chosen = new Set(ids)
  let changed = false

  const next = nodes.map((node) => {
    const selected = chosen.has(node.id)

    if (Boolean(node.selected) === selected) return node

    changed = true

    return { ...node, selected }
  })

  return changed ? next : nodes
}
