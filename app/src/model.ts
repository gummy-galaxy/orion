import type { Node } from '@xyflow/react'
import { migrateTask, type Source } from './sources'

export const TASK_W = 216
export const TASK_H = 72
export const PAD = 32
export const HEAD = 78

/** `blocked` is set by hand for blockers outside the graph; dependency blocking is derived. */
export type Status = 'todo' | 'active' | 'review' | 'blocked' | 'deferred' | 'done'
export type Who = 'you' | 'review' | 'ci'
export type ViewStatus = 'ready' | 'active' | 'review' | 'blocked' | 'deferred' | 'done'
/**
 * A pull request that exists, one that is expected but not opened yet, a step with no
 * pull request, a gate that opens once everything it waits on is done, or a note.
 * Notes are annotations, not work: they pass blocking through. Sources decide the
 * first three; see `sources.ts`.
 */
export type ItemKind = 'pr' | 'placeholder' | 'step' | 'gate' | 'note'

export type TaskData = {
  kind: 'task'
  label: string
  itemKind: ItemKind
  status: Status
  /** What the card stands for, in the order they were attached. Snapshots inside are written by `orion sync`. */
  sources?: Source[]
  note?: string
  who?: Who
}
export type GithubState = {
  state: 'OPEN' | 'MERGED' | 'CLOSED'
  draft: boolean
  reviewDecision?: 'APPROVED' | 'CHANGES_REQUESTED' | 'REVIEW_REQUIRED'
  /** GitHub's MergeStateStatus: `BLOCKED` or `DIRTY` keep an approved pull request from merging. */
  mergeStateStatus?: string
  /** Whoever's latest review approves. */
  approvers?: string[]
  title: string
  url: string
  author: string
  mine: boolean
  requestedFromYou: boolean
  updatedAt: string
  additions: number
  deletions: number
  checks?: 'SUCCESS' | 'FAILURE' | 'ERROR' | 'PENDING' | 'EXPECTED'
  checkedAt: string
}
export type UnplacedPr = {
  repo: string
  number: number
  title: string
  url: string
  draft: boolean
  updatedAt: string
  additions: number
  deletions: number
  matches: { id: string; score: number }[]
}
export type GithubSnapshot = { viewer: string; checkedAt: string; unplaced: UnplacedPr[] }
/**
 * How reflow arranges a group's children: `auto` flows them by dependency and wraps long rows, `grid` places them
 * `columns` across in dependency order, and `custom` keeps them where they were put.
 */
export type Arrange = 'auto' | 'grid' | 'custom'
/** `layout` asks the app to lay out a group the CLI changed: `pending` for a new group, `refit` to tidy one in place. */
export type ClusterData = {
  kind: 'cluster'
  label: string
  blurb?: string
  layout?: 'pending' | 'refit'
  arrange?: Arrange
  /** Only for `grid`; reflow uses `WRAP` when unset. */
  columns?: number
}
export type ImageData = { kind: 'image'; label: string; asset: string; workspace: string }
export type TaskNode = Node<TaskData, 'task'>
/** Stand-in for work outside the opened group that links into it. Never stored. */
export type GhostData = { kind: 'ghost'; taskId: string; label: string; where: string; status: ViewStatus; side: 'in' | 'out' }
export type GhostNode = Node<GhostData, 'ghost'>
export type ClusterNode = Node<ClusterData, 'cluster'>
export type ImageNode = Node<ImageData, 'image'>
export type AppNode = TaskNode | ClusterNode | ImageNode

/** `origin` marks links Orion derived itself: stacked pull requests, or a reference in a title, body or branch. */
export type Link = { id: string; from: string; to: string; kind: 'blocks' | 'related'; origin?: 'stack' | 'mention' }

export const STATUS_LABEL: Record<ViewStatus, string> = {
  ready: 'Ready',
  active: 'In progress',
  review: 'In review',
  blocked: 'Blocked',
  deferred: 'Deferred',
  done: 'Done',
}

export const WHO_LABEL: Record<Who, string> = { you: 'Your move', review: 'Waiting on review', ci: 'Waiting on CI' }

/** Carries cards saved before typed sources over to them, as the CLI does when it reads a file. */
export function migrateNodes(nodes: AppNode[]): AppNode[] {
  return nodes.map((n) => {
    if (n.type !== 'task') return n
    const data = migrateTask(n.data)
    return data === n.data ? n : { ...n, data }
  })
}

export const isCluster = (n: AppNode): n is ClusterNode => n.type === 'cluster'
export const isTask = (n: AppNode): n is TaskNode => n.type === 'task'
export const isImage = (n: AppNode): n is ImageNode => n.type === 'image'
export const isNote = (n: AppNode | undefined): boolean => !!n && isTask(n) && n.data.itemKind === 'note'

export function byId(nodes: AppNode[]): Map<string, AppNode> {
  return new Map(nodes.map((n) => [n.id, n]))
}

/** Parent chain from the nearest parent up to the top level. */
export function ancestors(id: string, map: Map<string, AppNode>): string[] {
  const out: string[] = []
  let cur = map.get(id)?.parentId
  while (cur) {
    out.push(cur)
    cur = map.get(cur)?.parentId
  }
  return out
}

export function sizeOf(n: AppNode): { w: number; h: number } {
  if (isTask(n)) return { w: TASK_W, h: TASK_H }
  return { w: n.width ?? 320, h: n.height ?? 200 }
}

export function absPos(n: AppNode, map: Map<string, AppNode>): { x: number; y: number } {
  let x = n.position.x
  let y = n.position.y
  for (const a of ancestors(n.id, map)) {
    const p = map.get(a)
    if (p) {
      x += p.position.x
      y += p.position.y
    }
  }
  return { x, y }
}

/** Fills in the React Flow fields every node needs, so saved data stays minimal. */
function hydrate(n: AppNode): AppNode {
  if (isTask(n)) return { ...n, width: TASK_W, height: TASK_H, expandParent: !!n.parentId }
  if (isImage(n)) return { ...n, width: n.width ?? 256, height: n.height ?? 256, expandParent: !!n.parentId }
  return { ...n, dragHandle: '.drag', expandParent: !!n.parentId }
}

/** React Flow needs parents before children. */
function sortNodes(nodes: AppNode[]): AppNode[] {
  const map = byId(nodes)
  return [...nodes].sort((a, b) => ancestors(a.id, map).length - ancestors(b.id, map).length)
}

/**
 * Shrinks or grows every group to hug its children, deepest first, and removes
 * groups left empty. Children keep their place on screen.
 */
function fitGroups(nodes: AppNode[]): AppNode[] {
  const map = new Map(nodes.map((n) => [n.id, { ...n } as AppNode]))
  const depth = (id: string) => ancestors(id, map).length
  const clusters = [...map.values()].filter(isCluster).sort((a, b) => depth(b.id) - depth(a.id))
  for (const g of clusters) {
    const kids = [...map.values()].filter((n) => n.parentId === g.id)
    if (!kids.length) {
      map.delete(g.id)
      continue
    }
    let minX = Infinity
    let minY = Infinity
    let maxX = -Infinity
    let maxY = -Infinity
    for (const k of kids) {
      const s = sizeOf(k)
      minX = Math.min(minX, k.position.x)
      minY = Math.min(minY, k.position.y)
      maxX = Math.max(maxX, k.position.x + s.w)
      maxY = Math.max(maxY, k.position.y + s.h)
    }
    const dx = minX - PAD
    const dy = minY - HEAD
    for (const k of kids) k.position = { x: k.position.x - dx, y: k.position.y - dy }
    g.position = { x: g.position.x + dx, y: g.position.y + dy }
    g.width = maxX - minX + PAD * 2
    g.height = maxY - minY + HEAD + PAD
  }
  return [...map.values()]
}

export function normalize(nodes: AppNode[]): AppNode[] {
  return sortNodes(fitGroups(nodes)).map(hydrate)
}

/** Wraps the selection in a new group under the selection's nearest shared parent. */
export function groupSelection(nodes: AppNode[]): { nodes: AppNode[]; groupId: string } | null {
  const map = byId(nodes)
  const sel = nodes.filter((n) => n.selected && !n.hidden && !ancestors(n.id, map).some((a) => map.get(a)?.selected))
  if (!sel.length) return null
  const chains = sel.map((n) => ancestors(n.id, map))
  const parent = chains[0].find((a) => chains.every((c) => c.includes(a)))
  const parentNode = parent ? map.get(parent) : undefined
  const origin = parentNode ? absPos(parentNode, map) : { x: 0, y: 0 }
  const abs = new Map(sel.map((n) => [n.id, absPos(n, map)]))
  const minX = Math.min(...[...abs.values()].map((p) => p.x))
  const minY = Math.min(...[...abs.values()].map((p) => p.y))
  const gpos = { x: minX - origin.x - PAD, y: minY - origin.y - HEAD }
  const groupId = 'g-' + Date.now().toString(36)
  const group: ClusterNode = {
    id: groupId,
    type: 'cluster',
    position: gpos,
    parentId: parent,
    data: { kind: 'cluster', label: 'New group' },
    selected: true,
  }
  const next = nodes.map((n): AppNode => {
    const p = abs.get(n.id)
    if (p) return { ...n, parentId: groupId, selected: false, position: { x: p.x - origin.x - gpos.x, y: p.y - origin.y - gpos.y } }
    return n.selected ? { ...n, selected: false } : n
  })
  return { nodes: normalize([...next, group]), groupId }
}

/** Dissolves the given groups, handing their children to the group's parent in place. */
export function ungroup(nodes: AppNode[], ids: string[]): AppNode[] {
  let next = nodes
  for (const id of ids) {
    const g = next.find((n) => n.id === id)
    if (!g || !isCluster(g)) continue
    next = next
      .filter((n) => n.id !== id)
      .map((n): AppNode =>
        n.parentId === id
          ? { ...n, parentId: g.parentId, selected: true, position: { x: n.position.x + g.position.x, y: n.position.y + g.position.y } }
          : n,
      )
  }
  return normalize(next)
}

export function descendants(id: string, nodes: AppNode[]): Set<string> {
  const out = new Set<string>()
  const walk = (pid: string) => {
    for (const n of nodes)
      if (n.parentId === pid && !out.has(n.id)) {
        out.add(n.id)
        walk(n.id)
      }
  }
  walk(id)
  return out
}

/**
 * How far review has come on an open pull request: approved and mergeable, approved but blocked from merging,
 * or approved by someone without the code owner yet. Null when review hasn't produced an approval.
 */
export function reviewStage(github: GithubState | undefined): 'Approved' | 'Merge blocked' | 'Owner pending' | null {
  if (!github || github.state !== 'OPEN' || github.draft) return null
  if (github.reviewDecision === 'APPROVED')
    return github.mergeStateStatus === 'BLOCKED' || github.mergeStateStatus === 'DIRTY' ? 'Merge blocked' : 'Approved'
  return github.approvers?.length ? 'Owner pending' : null
}

/** "Merged · checked 2h ago" for a synced pull request. */
export function githubSummary(github: GithubState, now = Date.now()) {
  const state =
    github.state === 'OPEN'
      ? github.draft
        ? 'Draft'
        : (reviewStage(github) ?? REVIEW_LABEL[github.reviewDecision ?? ''] ?? 'Open')
      : github.state.charAt(0) + github.state.slice(1).toLowerCase()
  return `${state} on GitHub · checked ${relativeTime(github.checkedAt, now)}`
}

export function relativeTime(iso: string, now = Date.now()) {
  const minutes = Math.max(0, Math.round((now - Date.parse(iso)) / 60000))
  const ago =
    minutes < 1
      ? 'just now'
      : minutes < 60
        ? `${minutes}m ago`
        : minutes < 1440
          ? `${Math.round(minutes / 60)}h ago`
          : `${Math.round(minutes / 1440)}d ago`
  return ago
}

const REVIEW_LABEL: Record<string, string> = { APPROVED: 'Approved', CHANGES_REQUESTED: 'Changes requested', REVIEW_REQUIRED: 'Awaiting review' }
