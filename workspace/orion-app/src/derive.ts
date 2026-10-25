import { createContext } from 'react'
import { descendants } from './hierarchy/descendants'
import { indexNodes } from './hierarchy/indexNodes'
import type { NodeIndex } from './hierarchy/types'
import {
  isCluster,
  isComponent,
  isTask,
  type AppNode,
  type Link,
  type PullReadiness,
  type RefChecks,
  type SourceRef as RefData,
  type TaskNode,
  type ViewStatus,
} from './model'
import type { Rarity } from './rarity'
import type { GroupResize } from './resize/types'

export type TraceRole = 'self' | 'up' | 'down' | 'related' | 'dim'
/** How a link out of a card reads: moving, held behind work that's stuck, or still, out of a component that carries no work. */
export type Flow = 'live' | 'held' | 'still'
export type GroupStats = { total: number; done: number; ready: number; blocked: number; outside: number }
export type SourceRef = { domain: string; label: string; href?: string }

/**
 * The graph facts `orion serve` derives and sends beside the document, on `GET /api/orion` and on `orion:changed`
 * events. Maps are keyed by item id. The app reads them and never works out status or blocking itself.
 */
export type Derived = {
  status: Record<string, ViewStatus>
  flow: Record<string, Flow>
  leverage: Record<string, number>
  upstream: Record<string, number>
  rarity: Record<string, Rarity>
  groups: Record<string, GroupStats>
  /** Progress across every card on the canvas, counted the way each group's is. */
  canvas: GroupStats
  /** Cards snoozed right now, mapped to the UTC time they wake. */
  snoozed: Record<string, string>
  /** Open work where it's your move. Blocked work waits, and snoozed work is set aside until it wakes. */
  attention: Record<string, true>
  /** Pull request facts for cards where a CI job snooze leaves out a failure, shown over the card's own. */
  pulls: Record<string, SnoozedFacts>
}

/** A failed CI job a snooze leaves out on a card, and when the snooze ends if it's timed. */
export type SnoozedJob = { name: string; until?: string }

/**
 * A card's pull request facts with its snoozed CI jobs left out, so a card whose only failures are snoozed reads as
 * running or passing. `wakesAt` is when the soonest timed snooze ends and the facts change again.
 */
export type SnoozedFacts = { readiness?: PullReadiness; checks?: RefChecks; snoozed: SnoozedJob[]; wakesAt?: string }

export type Actions = {
  reflow: (groupId: string) => void
  open: (groupId: string) => void
  /** Closes out a finished card and the finished cards chained to it. */
  celebrate: (id: string) => void
  resizeGroup: GroupResize
}

export const ActionsContext = createContext<Actions | null>(null)

/** Where one ref comes from: its URL's host when it has a valid one, otherwise the source that recorded it. */
function sourceOf(ref: RefData): SourceRef {
  const href = ref.url

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

/** Every ref on a card gets a badge, once per source, kind, and key. A card with no refs gets none. */
export function sourcesOf(task: TaskNode): SourceRef[] {
  const sources = new Map<string, SourceRef>()

  for (const ref of task.data.refs ?? []) {
    const key = `${ref.source}:${ref.kind}:${ref.key.toLowerCase()}`

    if (!sources.has(key)) sources.set(key, sourceOf(ref))
  }

  return [...sources.values()]
}

/** A group's badges: the badges of every card inside it, once per domain and label, linked ones winning over unlinked ones. */
export function sourcesOfGroup(members: TaskNode[]): SourceRef[] {
  const groupSources = new Map<string, SourceRef>()

  for (const task of members) {
    for (const source of sourcesOf(task)) {
      const key = `${source.domain}:${source.label}`

      if (!groupSources.get(key)?.href) groupSources.set(key, source)
    }
  }

  return [...groupSources.values()].sort((a, b) => a.domain.localeCompare(b.domain) || a.label.localeCompare(b.label))
}

/** Blocking links as adjacency lists, so hover tracing can walk up and down the graph. */
export function linkGraph(links: Link[]) {
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

/** Where each card's work comes from, and what each group gathers from the cards inside it. Badges only: nothing here decides status. */
export function deriveSources(nodes: AppNode[], index: NodeIndex = indexNodes(nodes)): Map<string, SourceRef[]> {
  const tasks = new Map(nodes.filter(isTask).map((node) => [node.id, node as TaskNode]))
  const sources = new Map<string, SourceRef[]>()

  for (const task of tasks.values()) sources.set(task.id, sourcesOf(task))

  for (const group of nodes.filter(isCluster)) {
    const inside = descendants(group.id, index.children)
    const members: TaskNode[] = []

    for (const id of inside) {
      const task = tasks.get(id)

      if (task) members.push(task)
    }

    sources.set(group.id, sourcesOfGroup(members))
  }

  return sources
}

/** The server's derived values as maps, which cards and the canvas read by id. */
export type ServerFacts = {
  status: Map<string, ViewStatus>
  flow: Map<string, Flow>
  leverage: Map<string, number>
  upstream: Map<string, number>
  rarity: Map<string, Rarity>
  groups: Map<string, GroupStats>
  canvas: GroupStats
  snoozed: Map<string, string>
  attention: Set<string>
  pulls: Map<string, SnoozedFacts>
}

const NO_PROGRESS: GroupStats = { total: 0, done: 0, ready: 0, blocked: 0, outside: 0 }

export function toServerFacts(derived: Derived | null): ServerFacts {
  return {
    status: new Map(Object.entries(derived?.status ?? {})),
    flow: new Map(Object.entries(derived?.flow ?? {})),
    leverage: new Map(Object.entries(derived?.leverage ?? {})),
    upstream: new Map(Object.entries(derived?.upstream ?? {})),
    rarity: new Map(Object.entries(derived?.rarity ?? {})),
    groups: new Map(Object.entries(derived?.groups ?? {})),
    canvas: derived?.canvas ?? NO_PROGRESS,
    snoozed: new Map(Object.entries(derived?.snoozed ?? {})),
    attention: new Set(Object.keys(derived?.attention ?? {})),
    pulls: new Map(Object.entries(derived?.pulls ?? {})),
  }
}

/**
 * What cards and the canvas read: the server's values, plus sources and the blocking links for tracing. A card the
 * server hasn't derived yet (one just added, or no server at all) shows its recorded status, with no blocking and
 * zero leverage, upstream work, and rarity, until the server answers.
 */
export function buildWork(facts: ServerFacts, nodes: AppNode[], links: Link[], index: NodeIndex = indexNodes(nodes)) {
  let status = facts.status

  for (const node of nodes) {
    // Components have no status, so they never get one to fall back on.
    if (!isTask(node) || isComponent(node) || status.has(node.id)) continue

    if (status === facts.status) status = new Map(facts.status)

    status.set(node.id, node.data.status === 'todo' ? 'ready' : node.data.status)
  }

  return { ...facts, status, sources: deriveSources(nodes, index), ...linkGraph(links) }
}

export type Work = ReturnType<typeof buildWork>

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
