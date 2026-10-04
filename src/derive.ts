import { createContext } from 'react'
import { descendants, isCluster, isTask, type AppNode, type Link, type TaskNode, type ViewStatus } from './model'

export type TraceRole = 'self' | 'up' | 'down' | 'dim'
export type GroupStats = { total: number; done: number; ready: number; blocked: number; outside: number }

export type Derived = {
  status: Map<string, ViewStatus>
  leverage: Map<string, number>
  groups: Map<string, GroupStats>
  trace: Map<string, TraceRole> | null
  collapsed: Set<string>
  zoom: number
}

export type Actions = {
  reflow: (groupId: string) => void
  open: (groupId: string) => void
}

export const DerivedContext = createContext<Derived | null>(null)
export const ActionsContext = createContext<Actions | null>(null)

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
export function deriveWork(nodes: AppNode[], links: Link[]) {
  const tasks = new Map(nodes.filter(isTask).map((n) => [n.id, n as TaskNode]))
  const { preds, succs } = graph(links)
  const open = (id: string) => tasks.get(id)?.data.status !== 'done'

  const status = new Map<string, ViewStatus>()
  for (const t of tasks.values()) {
    const s = t.data.status
    if (s === 'done' || s === 'deferred' || s === 'blocked') status.set(t.id, s)
    else if ((preds.get(t.id) ?? []).some(open)) status.set(t.id, 'blocked')
    else status.set(t.id, s === 'todo' ? 'ready' : s)
  }

  const leverage = new Map<string, number>()
  const downstream = new Map<string, Set<string>>()
  for (const t of tasks.values()) {
    if (!open(t.id)) continue
    // Parked work doesn't count toward what finishing something unlocks.
    const d = walk(t.id, succs, (id) => open(id) && tasks.get(id)?.data.status !== 'deferred')
    downstream.set(t.id, d)
    leverage.set(t.id, d.size)
  }

  const groups = new Map<string, GroupStats>()
  for (const g of nodes.filter(isCluster)) {
    const inside = descendants(g.id, nodes)
    const s: GroupStats = { total: 0, done: 0, ready: 0, blocked: 0, outside: 0 }
    const reach = new Set<string>()
    for (const id of inside) {
      const st = status.get(id)
      if (!st) continue
      s.total++
      if (st === 'done') s.done++
      if (st === 'ready') s.ready++
      if (st === 'blocked') s.blocked++
      for (const d of downstream.get(id) ?? []) if (!inside.has(d)) reach.add(d)
    }
    s.outside = reach.size
    groups.set(g.id, s)
  }

  return { status, leverage, groups, preds, succs }
}

export function traceFrom(id: string, preds: Map<string, string[]>, succs: Map<string, string[]>, ids: string[]) {
  const up = walk(id, preds, () => true)
  const down = walk(id, succs, () => true)
  const roles = new Map<string, TraceRole>()
  for (const n of ids) roles.set(n, n === id ? 'self' : up.has(n) ? 'up' : down.has(n) ? 'down' : 'dim')
  return roles
}
