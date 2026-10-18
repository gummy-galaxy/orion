import type { Work } from '../derive'
import { ancestors, byId, getItemKind, getPullRef, getPullRequestNumber, isTask, type AppNode, type ClusterData } from '../model'
import type { TableRow } from './types'

const readPriority = (details: Record<string, unknown> | undefined) => {
  const priority = details?.priority

  return typeof priority === 'string' ? priority : undefined
}

/**
 * Every card inside `root` at any depth, or on the whole canvas when `root` is null, as table rows. Spike #102: a
 * database view lists entities, so once #122 lets one card sit in several places, this reads cards rather than
 * placements, and the group column lists each place it sits.
 */
export function getTableRows(nodes: AppNode[], work: Work, root: string | null): TableRow[] {
  const nodeMap = byId(nodes)
  const rows: TableRow[] = []

  for (const node of nodes) {
    if (!isTask(node)) continue

    const chain = ancestors(node.id, nodeMap)

    if (root && !chain.includes(root)) continue

    const groups = chain.map((id) => (nodeMap.get(id)?.data as ClusterData | undefined)?.label ?? '').reverse()
    const below = root ? chain.slice(0, chain.indexOf(root)).reverse() : [...chain].reverse()
    const data = node.data
    const refs = data.refs ?? []
    const pull = getPullRef(data)
    const number = getPullRequestNumber(pull)
    const draft = pull?.details?.draft
    const lines = pull?.additions !== undefined && pull.deletions !== undefined ? pull.additions + pull.deletions : undefined

    rows.push({
      id: node.id,
      label: data.label,
      kind: getItemKind(data),
      status: data.itemKind === 'component' || data.itemKind === 'note' ? undefined : work.status.get(node.id),
      recordedStatus: data.status,
      groupId: node.parentId,
      groups,
      groupPath: below.map((id) => (nodeMap.get(id)?.data as ClusterData | undefined)?.label ?? '').join(' › '),
      repo: data.repo,
      note: data.note,
      refs,
      pr: number === undefined ? undefined : String(number),
      draft: typeof draft === 'boolean' ? String(draft) : undefined,
      snoozed: work.snoozed.has(node.id),
      who: data.who,
      priority: refs.map((ref) => readPriority(ref.details)).find(Boolean),
      lines,
    })
  }

  // Canvas reading order: group by group, then top to bottom and left to right inside each.
  const place = new Map(nodes.map((node) => [node.id, node.position]))

  return rows.sort((a, b) => {
    const path = a.groups.join('\0').localeCompare(b.groups.join('\0'))
    const first = place.get(a.id)!
    const second = place.get(b.id)!

    return path || first.y - second.y || first.x - second.x
  })
}
