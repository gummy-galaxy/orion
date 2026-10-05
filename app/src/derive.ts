import { createContext } from 'react'
import { descendants, isCluster, isNote, isTask, type AppNode, type Link, type TaskNode, type ViewStatus } from './model'
import { badgeGroup, badgeOf, ordered, type Badge } from './sources'

export type TraceRole = 'self' | 'up' | 'down' | 'dim'
export type GroupStats = { total: number; done: number; ready: number; blocked: number; outside: number }

export type Derived = {
  status: Map<string, ViewStatus>
  leverage: Map<string, number>
  groups: Map<string, GroupStats>
  sources: Map<string, Badge[]>
  trace: Map<string, TraceRole> | null
  collapsed: Set<string>
  zoom: number
  /** While ⌘ is held: what needs you, keyed by the card or folded group that shows it. */
  attention: Map<string, AttentionMark> | null
}

export type Actions = {
  reflow: (groupId: string) => void
  open: (groupId: string) => void
}

export const DerivedContext = createContext<Derived | null>(null)
export const ActionsContext = createContext<Actions | null>(null)

const ORION: Badge = { icon: 'orion', domain: 'orion', label: 'Orion' }

function badgesOf(task: TaskNode, owner: string): Badge[] {
  const list = ordered(task.data).map((source) => badgeOf(source, owner))
  return list.length ? list : [ORION]
}

function graph(links: Link[]) {
  const preds = new Map<string, string[]>()
  const succs = new Map<string, string[]>()
  for (const l of links) {
    if (l.kind !== 'blocks') continue
    if (!succs.has(l.from)) succs.set(l.from, [])
    if (!preds.has(l.to)) preds.set(l.to, [])
    succs.get(l.from)!.push(l.to)
    preds.get(l.to)!.push(l.from)
  }
  return { preds, succs }
}

function walk(start: string, next: Map<string, string[]>, keep: (id: string) => boolean): Set<string> {
  const seen = new Set<string>()
  const stack = [start]
  while (stack.length) {
    const cur = stack.pop()!
    for (const n of next.get(cur) ?? []) {
      if (!seen.has(n) && keep(n)) {
        seen.add(n)
        stack.push(n)
      }
    }
  }
  return seen
}

/** Work-state facts that don't depend on the viewport: status, leverage, and per-group progress. */
export function deriveWork(nodes: AppNode[], links: Link[], owner = 'flipbook-labs') {
  const tasks = new Map(nodes.filter(isTask).map((n) => [n.id, n as TaskNode]))
  const sources = new Map<string, Badge[]>()
  for (const task of tasks.values()) sources.set(task.id, badgesOf(task, owner))
  const { preds, succs } = graph(links)
  const isNote = (id: string) => tasks.get(id)?.data.itemKind === 'note'
  const isGate = (id: string) => tasks.get(id)?.data.itemKind === 'gate' && preds.has(id)
  // A note is open while anything feeding into it is, so blocking passes through notes. Gates pass it
  // through the same way but count as work: one is done once everything it waits on is.
  const noteOpen = new Map<string, boolean>()
  const open = (id: string, seen = new Set<string>()): boolean => {
    const t = tasks.get(id)
    if (!t) return false
    if (!isNote(id) && !isGate(id)) return t.data.status !== 'done'
    if (noteOpen.has(id)) return noteOpen.get(id)!
    if (seen.has(id)) return false
    seen.add(id)
    const r = (preds.get(id) ?? []).some((p) => open(p, seen))
    noteOpen.set(id, r)
    return r
  }

  const status = new Map<string, ViewStatus>()
  for (const t of tasks.values()) {
    const s = t.data.status
    if (isNote(t.id) || (isGate(t.id) && s !== 'deferred')) status.set(t.id, open(t.id) ? 'blocked' : 'done')
    else if (s === 'done' || s === 'deferred' || s === 'blocked') status.set(t.id, s)
    else if ((preds.get(t.id) ?? []).some((p) => open(p))) status.set(t.id, 'blocked')
    else status.set(t.id, s === 'todo' ? 'ready' : s)
  }

  const leverage = new Map<string, number>()
  const downstream = new Map<string, Set<string>>()
  for (const t of tasks.values()) {
    if (isNote(t.id) || !open(t.id)) continue
    // Parked work doesn't count toward what finishing something unlocks, and notes aren't work.
    const reach = walk(t.id, succs, (id) => open(id) && tasks.get(id)?.data.status !== 'deferred')
    const d = new Set([...reach].filter((id) => !isNote(id)))
    downstream.set(t.id, d)
    leverage.set(t.id, d.size)
  }

  const groups = new Map<string, GroupStats>()
  for (const g of nodes.filter(isCluster)) {
    const inside = descendants(g.id, nodes)
    const s: GroupStats = { total: 0, done: 0, ready: 0, blocked: 0, outside: 0 }
    const groupSources = new Map<string, Badge>()
    const reach = new Set<string>()
    for (const id of inside) {
      for (const badge of sources.get(id) ?? []) groupSources.set(`${badgeGroup(badge)}:${badge.label}`, badge)
      const st = status.get(id)
      if (!st || isNote(id)) continue
      s.total++
      if (st === 'done') s.done++
      if (st === 'ready') s.ready++
      if (st === 'blocked') s.blocked++
      for (const d of downstream.get(id) ?? []) if (!inside.has(d)) reach.add(d)
    }
    s.outside = reach.size
    groups.set(g.id, s)
    sources.set(
      g.id,
      [...groupSources.values()].sort((a, b) => badgeGroup(a).localeCompare(badgeGroup(b)) || a.label.localeCompare(b.label)),
    )
  }

  return { status, leverage, groups, sources, preds, succs }
}

export function traceFrom(id: string, preds: Map<string, string[]>, succs: Map<string, string[]>, ids: string[]) {
  const up = walk(id, preds, () => true)
  const down = walk(id, succs, () => true)
  const roles = new Map<string, TraceRole>()
  for (const n of ids) roles.set(n, n === id ? 'self' : up.has(n) ? 'up' : down.has(n) ? 'down' : 'dim')
  return roles
}

/** Cards where it's your move, gathered onto whatever shows them. */
export type AttentionMark = { ids: string[] }

/** Open work where it's your move. Blocked work can't move, so it waits. */
export function needsAttention(nodes: AppNode[], status: Map<string, ViewStatus>) {
  const out: string[] = []
  for (const n of nodes) {
    if (!isTask(n) || isNote(n) || n.data.who !== 'you') continue
    const st = status.get(n.id)
    if (st && st !== 'done' && st !== 'deferred' && st !== 'blocked') out.push(n.id)
  }
  return out
}
