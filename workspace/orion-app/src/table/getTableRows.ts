import { ancestors, byId, cardLabel, getPrimaryRef, isTask, isWork, type AppNode, type ClusterData, type ViewStatus } from '../model'
import type { TableRow } from './types'

const PATH_SEPARATOR = '\0'

/**
 * Every card inside `root` at any depth, or on the whole canvas when `root` is null, as table rows. Rows sort by the
 * groups they sit in, with loose cards first, and then by label.
 */
export function getTableRows(nodes: AppNode[], statuses: Map<string, ViewStatus>, root: string | null): TableRow[] {
  const nodeMap = byId(nodes)
  const rows: TableRow[] = []

  for (const node of nodes) {
    if (!isTask(node)) continue

    const chain = ancestors(node.id, nodeMap)
    const inside = root ? chain.indexOf(root) : chain.length

    if (inside < 0) continue

    rows.push({
      id: node.id,
      label: cardLabel(node),
      kind: node.data.itemKind,
      status: isWork(node) ? (statuses.get(node.id) ?? 'ready') : undefined,
      groups: chain
        .slice(0, inside)
        .reverse()
        .map((id) => (nodeMap.get(id)?.data as ClusterData | undefined)?.label ?? ''),
      ref: getPrimaryRef(node.data)?.key,
    })
  }

  return rows.sort(
    (a, b) =>
      a.groups.join(PATH_SEPARATOR).localeCompare(b.groups.join(PATH_SEPARATOR)) || a.label.localeCompare(b.label) || a.id.localeCompare(b.id),
  )
}
