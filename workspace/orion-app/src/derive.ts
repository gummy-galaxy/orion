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
import { isSameRef } from './refs/isSameRef'
import type { Rarity } from './rarity'
import type { GroupResize } from './resize/types'

export type TraceRole = 'self' | 'up' | 'down' | 'related' | 'dim'
/**
 * How a link out of a card reads: moving, held behind work that's stuck, or still, out of a component that carries no
 * work.
 */
export type Flow = 'live' | 'held' | 'still'
export type GroupStats = { total: number; done: number; ready: number; blocked: number; outside: number }
export type SourceRef = { domain: string; label: string; href?: string }

/**
 * The server works out each card's status, what blocks it, and the other facts below from the canvas. It sends them
 * beside the document, both from `GET /api/orion` and with each `orion:changed` event, keyed by item id. The app reads
 * them rather than working these out itself. The one exception is a card the server hasn't reached yet, which
 * `buildWork` covers.
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
  /**
   * A failing CI job can be snoozed so it stops counting against its pull request. For each card where that hides a
   * failure, this holds the pull request's facts without the snoozed jobs, which the card shows in place of its own.
   */
  pulls: Record<string, SnoozedFacts>
}

/** A failing CI job that's snoozed on a card, and when the snooze ends if it has an end. */
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
  const seen: RefData[] = []

  for (const ref of task.data.refs ?? []) {
    if (!seen.some((other) => other.source === ref.source && isSameRef(other, ref))) seen.push(ref)
  }

  return seen.map(sourceOf)
}

/**
 * A group's badges: the badges of every card inside it, once per domain and label, linked ones winning over unlinked
 * ones.
 */
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

/**
 * Where each card's work comes from, and what each group gathers from the cards inside it. Badges only: nothing here
 * decides status.
 */
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
 * Gathers everything cards and the canvas read: the server's facts, each card's source badges, and the blocking links
 * that hover tracing follows.
 *
 * The server may not have derived a card yet, because it was just added or no server is running. Until it does, the
 * card shows the status saved on it, with to-do shown as ready since nothing has checked what blocks it. The server's
 * other facts leave the card out.
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
export function traceFrom(
  id: string,
  predecessors: Map<string, string[]>,
  successors: Map<string, string[]>,
  ids: string[],
  related: string[] = [],
) {
  const up = walk(id, predecessors, () => true)
  const down = walk(id, successors, () => true)
  const near = new Set(related)
  const roles = new Map<string, TraceRole>()

  for (const node of ids)
    roles.set(
      node,
      node === id ? 'self' : up.has(node) ? 'up' : down.has(node) ? 'down' : near.has(node) ? 'related' : 'dim',
    )

  return roles
}

/** Cards where it's your move, gathered onto whatever shows them. */
export type AttentionMark = { ids: string[] }
