import { createContext } from 'react'
import { descendants, getPrimaryRef, isCluster, isNote, isTask, type AppNode, type Link, type TaskNode, type ViewStatus } from './model'

export type TraceRole = 'self' | 'up' | 'down' | 'related' | 'dim'
/** How a link out of a card reads: moving, or held behind work that's stuck. */
export type Flow = 'live' | 'held'
export type GroupStats = { total: number; done: number; ready: number; blocked: number; outside: number }
export type SourceRef = { domain: string; label: string; href?: string }

export type Actions = {
  reflow: (groupId: string) => void
  open: (groupId: string) => void
  /** Clears the finish stamp on a card and on the finished cards chained to it. */
  celebrate: (id: string) => void
}

export const ActionsContext = createContext<Actions | null>(null)

/** Where a card's work comes from, or null for a card that only lives in Orion. */
function sourceOf(task: TaskNode): SourceRef | null {
  const ref = getPrimaryRef(task.data)
  const href = ref?.url

  if (!ref) return null

  if (href) {
    try {
      const url = new URL(href)

      if (url.hostname) {
        return { domain: url.hostname.toLowerCase(), label: ref.key, href }
      }
    } catch {
      // Fall back to the source when the URL is invalid.
    }
  }

  return { domain: ref.source, label: ref.key }
}

function graph(links: Link[]) {
  const predecessors = new Map<string, string[]>()
  const successors = new Map<string, string[]>()

  for (const link of links) {
    if (link.kind !== 'blocks') continue

    if (!successors.has(link.from)) successors.set(link.from, [])

    if (!predecessors.has(link.to)) predecessors.set(link.to, [])

    successors.get(link.from)!.push(link.to)
    predecessors.get(link.to)!.push(link.from)
  }

  return { preds: predecessors, succs: successors }
}

function walk(start: string, next: Map<string, string[]>, keep: (id: string) => boolean): Set<string> {
  const seen = new Set<string>()
  const stack = [start]

  while (stack.length) {
    const current = stack.pop()!

    for (const node of next.get(current) ?? []) {
      if (!seen.has(node) && keep(node)) {
        seen.add(node)
        stack.push(node)
      }
    }
  }

  return seen
}

/** Work-state facts that don't depend on the viewport: status, leverage, and per-group progress. */
export function deriveWork(nodes: AppNode[], links: Link[]) {
  const tasks = new Map(nodes.filter(isTask).map((node) => [node.id, node as TaskNode]))
  const sources = new Map<string, SourceRef[]>()

  for (const task of tasks.values()) {
    const source = sourceOf(task)

    sources.set(task.id, source ? [source] : [])
  }

  const { preds: predecessors, succs: successors } = graph(links)
  const isNote = (id: string) => tasks.get(id)?.data.itemKind === 'note'
  const isGate = (id: string) => tasks.get(id)?.data.itemKind === 'gate' && predecessors.has(id)
  // A note is open while anything feeding into it is, so blocking passes through notes. Gates pass it
  // through the same way but count as work: one is done once everything it waits on is.
  const noteOpen = new Map<string, boolean>()

  const open = (id: string, seen = new Set<string>()): boolean => {
    const task = tasks.get(id)

    if (!task) return false

    if (!isNote(id) && !isGate(id)) return task.data.status !== 'done'

    if (noteOpen.has(id)) return noteOpen.get(id)!

    if (seen.has(id)) return false

    seen.add(id)
    const result = (predecessors.get(id) ?? []).some((predecessor) => open(predecessor, seen))

    noteOpen.set(id, result)

    return result
  }

  const status = new Map<string, ViewStatus>()

  for (const task of tasks.values()) {
    const statusValue = task.data.status

    if (isNote(task.id) || (isGate(task.id) && statusValue !== 'deferred')) status.set(task.id, open(task.id) ? 'blocked' : 'done')
    else if (statusValue === 'done' || statusValue === 'deferred' || statusValue === 'blocked') status.set(task.id, statusValue)
    else if ((predecessors.get(task.id) ?? []).some((predecessor) => open(predecessor))) status.set(task.id, 'blocked')
    else status.set(task.id, statusValue === 'todo' ? 'ready' : statusValue)
  }

  // Links move unless they come out of work that's stuck. Notes pass on whatever reaches them.
  const flow = new Map<string, Flow>()

  const flowOf = (id: string, seen = new Set<string>()): Flow => {
    const known = flow.get(id)

    if (known) return known

    if (seen.has(id)) return 'held'

    seen.add(id)
    const statusValue = status.get(id)
    let flowValue: Flow

    if (statusValue === 'done') flowValue = 'live'
    else if (isNote(id)) flowValue = (predecessors.get(id) ?? []).some((predecessor) => flowOf(predecessor, seen) === 'live') ? 'live' : 'held'
    else flowValue = statusValue === 'blocked' || statusValue === 'deferred' ? 'held' : 'live'

    flow.set(id, flowValue)

    return flowValue
  }

  for (const id of tasks.keys()) flowOf(id)

  const leverage = new Map<string, number>()
  const downstream = new Map<string, Set<string>>()

  for (const task of tasks.values()) {
    if (isNote(task.id) || !open(task.id)) continue

    // Parked work doesn't count toward what finishing something unlocks, and notes aren't work.
    const reach = walk(task.id, successors, (id) => open(id) && tasks.get(id)?.data.status !== 'deferred')
    const downstreamNodes = new Set([...reach].filter((id) => !isNote(id)))

    downstream.set(task.id, downstreamNodes)
    leverage.set(task.id, downstreamNodes.size)
  }

  const groups = new Map<string, GroupStats>()

  for (const group of nodes.filter(isCluster)) {
    const inside = descendants(group.id, nodes)
    const stats: GroupStats = { total: 0, done: 0, ready: 0, blocked: 0, outside: 0 }
    const groupSources = new Map<string, SourceRef>()
    const reach = new Set<string>()

    for (const id of inside) {
      const task = tasks.get(id)

      if (task) {
        const source = sourceOf(task)
        const key = source && `${source.domain}:${source.label}`

        if (source && key && !groupSources.get(key)?.href) groupSources.set(key, source)
      }

      const statusValue = status.get(id)

      if (!statusValue || isNote(id)) continue

      stats.total++

      if (statusValue === 'done') stats.done++

      if (statusValue === 'ready') stats.ready++

      if (statusValue === 'blocked') stats.blocked++

      for (const downstreamNodes of downstream.get(id) ?? []) if (!inside.has(downstreamNodes)) reach.add(downstreamNodes)
    }

    stats.outside = reach.size
    groups.set(group.id, stats)
    sources.set(
      group.id,
      [...groupSources.values()].sort((a, b) => a.domain.localeCompare(b.domain) || a.label.localeCompare(b.label)),
    )
  }

  return { status, flow, leverage, groups, sources, preds: predecessors, succs: successors }
}

export type Work = ReturnType<typeof deriveWork>

/** What `id` needs, what it unlocks, and the cards related to it directly; everything else dims. */
export function traceFrom(id: string, predecessors: Map<string, string[]>, successors: Map<string, string[]>, ids: string[], related: string[] = []) {
  const up = walk(id, predecessors, () => true)
  const down = walk(id, successors, () => true)
  const near = new Set(related)
  const roles = new Map<string, TraceRole>()

  for (const node of ids) roles.set(node, node === id ? 'self' : up.has(node) ? 'up' : down.has(node) ? 'down' : near.has(node) ? 'related' : 'dim')

  return roles
}

/** Cards where it's your move, gathered onto whatever shows them. */
export type AttentionMark = { ids: string[] }

/** Open work where it's your move. Blocked work can't move, so it waits. */
export function needsAttention(nodes: AppNode[], status: Map<string, ViewStatus>) {
  const result: string[] = []

  for (const node of nodes) {
    if (!isTask(node) || isNote(node) || node.data.who !== 'you') continue

    const statusValue = status.get(node.id)

    if (statusValue && statusValue !== 'done' && statusValue !== 'deferred' && statusValue !== 'blocked') result.push(node.id)
  }

  return result
}
