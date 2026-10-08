import type { Node } from '@xyflow/react'

export const TASK_WIDTH = 216
export const TASK_HEIGHT = 72
export const GROUP_PADDING = 32
export const GROUP_HEADER_HEIGHT = 78

/** `blocked` is set by hand for blockers outside the graph; dependency blocking is derived. */
export type Status = 'todo' | 'active' | 'review' | 'blocked' | 'deferred' | 'done'
export type Who = 'you' | 'review' | 'ci'
export type ViewStatus = 'ready' | 'active' | 'review' | 'blocked' | 'deferred' | 'done'
/**
 * A pull request that exists, one that is expected but not opened yet, a step with no
 * pull request, or a note. Notes are annotations, not work: they pass blocking through.
 */
/** A gate is done once everything it waits on is, like a milestone or sign-off. */
export type ItemKind = 'pr' | 'placeholder' | 'step' | 'gate' | 'note'

export type TaskData = {
  kind: 'task'
  label: string
  itemKind: ItemKind
  status: Status
  repo?: string
  pr?: number
  host?: string
  branch?: string
  issue?: number
  /** An item from an ingested source other than a GitHub pull request, such as a Jira issue. */
  external?: {
    source: string
    key: string
    url?: string
    status?: string
    isDone?: boolean
    updatedAt?: string
    details?: Record<string, string>
  }
  activity?: { lastActiveAt: string; sessions: string[] }
  sources?: string[]
  note?: string
  who?: Who
  /** Written by `orion sync`; read-only here. */
  github?: GithubState
}
export type GithubState = {
  state: 'OPEN' | 'MERGED' | 'CLOSED'
  draft: boolean
  reviewDecision?: 'APPROVED' | 'CHANGES_REQUESTED' | 'REVIEW_REQUIRED'
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
export type UnplacedPullRequest = {
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
export type GithubSnapshot = { viewer: string; checkedAt: string; unplaced: UnplacedPullRequest[] }
/** How reflow arranges a group's children: `auto` flows them by dependency and wraps long rows, and `custom` keeps them where they were put. */
export type Arrange = 'auto' | 'custom'
/** `layout` asks the app to lay out a group the CLI changed: `pending` for a new group, `refit` to tidy one in place. */
export type ClusterData = {
  kind: 'cluster'
  label: string
  blurb?: string
  layout?: 'pending' | 'refit'
  arrange?: Arrange
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

const DEFAULT_GITHUB_OWNER = 'flipbook-labs'

/** A card's kind from its repository and pull request. Gates and notes keep their kind. */
export function getItemKind(data: Pick<TaskData, 'itemKind' | 'repo' | 'pr'>): ItemKind {
  if (data.itemKind === 'gate' || data.itemKind === 'note') return data.itemKind

  return data.pr && data.repo ? 'pr' : data.repo ? 'placeholder' : 'step'
}

export function getTaskTag(data: TaskData): string {
  if (data.external) return data.external.key

  if (data.repo && data.issue) return `${data.repo}#${data.issue}`

  if (data.repo && data.pr) return `${data.repo}#${data.pr}`

  return data.repo ?? (data.itemKind === 'gate' ? 'gate' : 'step')
}

export function getTaskUrl(data: TaskData, githubOwner = DEFAULT_GITHUB_OWNER): string | null {
  if (data.github?.url) return data.github.url

  if (data.repo && data.pr)
    return `https://${data.host ?? 'github.com'}/${data.repo.includes('/') ? data.repo : `${githubOwner}/${data.repo}`}/pull/${data.pr}`

  return data.external?.url ?? null
}

export const isCluster = (node: AppNode): node is ClusterNode => node.type === 'cluster'
export const isTask = (node: AppNode): node is TaskNode => node.type === 'task'
export const isImage = (node: AppNode): node is ImageNode => node.type === 'image'
export const isNote = (node: AppNode | undefined): boolean => !!node && isTask(node) && node.data.itemKind === 'note'

export function byId(nodes: AppNode[]): Map<string, AppNode> {
  return new Map(nodes.map((node) => [node.id, node]))
}

/** Parent chain from the nearest parent up to the top level. */
export function ancestors(id: string, nodeMap: Map<string, AppNode>): string[] {
  const result: string[] = []
  let current = nodeMap.get(id)?.parentId

  while (current) {
    result.push(current)
    current = nodeMap.get(current)?.parentId
  }

  return result
}

export function sizeOf(node: AppNode): { width: number; height: number } {
  if (isTask(node)) return { width: TASK_WIDTH, height: TASK_HEIGHT }

  return { width: node.width ?? 320, height: node.height ?? 200 }
}

export function absolutePosition(node: AppNode, nodeMap: Map<string, AppNode>): { x: number; y: number } {
  let x = node.position.x
  let y = node.position.y

  for (const ancestor of ancestors(node.id, nodeMap)) {
    const parentNode = nodeMap.get(ancestor)

    if (parentNode) {
      x += parentNode.position.x
      y += parentNode.position.y
    }
  }

  return { x, y }
}

/** Fills in the React Flow fields every node needs, so saved data stays minimal. */
function hydrate(node: AppNode): AppNode {
  if (isTask(node)) return { ...node, width: TASK_WIDTH, height: TASK_HEIGHT, expandParent: !!node.parentId }

  if (isImage(node)) return { ...node, width: node.width ?? 256, height: node.height ?? 256, expandParent: !!node.parentId }

  return { ...node, dragHandle: '.drag', expandParent: !!node.parentId }
}

/** React Flow needs parents before children. */
function sortNodes(nodes: AppNode[]): AppNode[] {
  const nodeMap = byId(nodes)

  return [...nodes].sort((a, b) => ancestors(a.id, nodeMap).length - ancestors(b.id, nodeMap).length)
}

/**
 * Shrinks or grows every group to hug its children, deepest first, and removes
 * groups left empty. Children keep their place on screen.
 */
function fitGroups(nodes: AppNode[]): AppNode[] {
  const nodeMap = new Map(nodes.map((node) => [node.id, { ...node } as AppNode]))
  const depth = (id: string) => ancestors(id, nodeMap).length
  const clusters = [...nodeMap.values()].filter(isCluster).sort((a, b) => depth(b.id) - depth(a.id))

  for (const group of clusters) {
    const children = [...nodeMap.values()].filter((node) => node.parentId === group.id)

    if (!children.length) {
      nodeMap.delete(group.id)
      continue
    }

    let minX = Infinity
    let minY = Infinity
    let maxX = -Infinity
    let maxY = -Infinity

    for (const child of children) {
      const size = sizeOf(child)

      minX = Math.min(minX, child.position.x)
      minY = Math.min(minY, child.position.y)
      maxX = Math.max(maxX, child.position.x + size.width)
      maxY = Math.max(maxY, child.position.y + size.height)
    }

    const deltaX = minX - GROUP_PADDING
    const deltaY = minY - GROUP_HEADER_HEIGHT

    for (const child of children) child.position = { x: child.position.x - deltaX, y: child.position.y - deltaY }

    group.position = { x: group.position.x + deltaX, y: group.position.y + deltaY }
    group.width = maxX - minX + GROUP_PADDING * 2
    group.height = maxY - minY + GROUP_HEADER_HEIGHT + GROUP_PADDING
  }

  return [...nodeMap.values()]
}

export function normalize(nodes: AppNode[]): AppNode[] {
  return sortNodes(fitGroups(nodes)).map(hydrate)
}

/** Wraps the selection in a new group under the selection's nearest shared parent. */
export function groupSelection(nodes: AppNode[]): { nodes: AppNode[]; groupId: string } | null {
  const nodeMap = byId(nodes)
  const selection = nodes.filter(
    (node) => node.selected && !node.hidden && !ancestors(node.id, nodeMap).some((ancestor) => nodeMap.get(ancestor)?.selected),
  )

  if (!selection.length) return null

  const chains = selection.map((node) => ancestors(node.id, nodeMap))
  const parent = chains[0].find((ancestor) => chains.every((chain) => chain.includes(ancestor)))
  const parentNode = parent ? nodeMap.get(parent) : undefined
  const origin = parentNode ? absolutePosition(parentNode, nodeMap) : { x: 0, y: 0 }
  const absolutePositions = new Map(selection.map((node) => [node.id, absolutePosition(node, nodeMap)]))
  const minX = Math.min(...[...absolutePositions.values()].map((position) => position.x))
  const minY = Math.min(...[...absolutePositions.values()].map((position) => position.y))
  const groupPosition = { x: minX - origin.x - GROUP_PADDING, y: minY - origin.y - GROUP_HEADER_HEIGHT }
  const groupId = 'g-' + Date.now().toString(36)
  const group: ClusterNode = {
    id: groupId,
    type: 'cluster',
    position: groupPosition,
    parentId: parent,
    data: { kind: 'cluster', label: 'New group' },
    selected: true,
  }
  const next = nodes.map((node): AppNode => {
    const position = absolutePositions.get(node.id)

    if (position)
      return {
        ...node,
        parentId: groupId,
        selected: false,
        position: { x: position.x - origin.x - groupPosition.x, y: position.y - origin.y - groupPosition.y },
      }

    return node.selected ? { ...node, selected: false } : node
  })

  return { nodes: normalize([...next, group]), groupId }
}

/** Dissolves the given groups, handing their children to the group's parent in place. */
export function ungroup(nodes: AppNode[], ids: string[]): AppNode[] {
  let next = nodes

  for (const id of ids) {
    const group = next.find((node) => node.id === id)

    if (!group || !isCluster(group)) continue

    next = next
      .filter((node) => node.id !== id)
      .map((node): AppNode =>
        node.parentId === id
          ? {
              ...node,
              parentId: group.parentId,
              selected: true,
              position: { x: node.position.x + group.position.x, y: node.position.y + group.position.y },
            }
          : node,
      )
  }

  return normalize(next)
}

export function descendants(id: string, nodes: AppNode[]): Set<string> {
  const result = new Set<string>()

  const walk = (parentId: string) => {
    for (const node of nodes)
      if (node.parentId === parentId && !result.has(node.id)) {
        result.add(node.id)
        walk(node.id)
      }
  }

  walk(id)

  return result
}

/** "Merged · checked 2h ago" for a synced pull request. */
export function githubSummary(github: GithubState, now = Date.now()) {
  const state =
    github.state === 'OPEN'
      ? github.draft
        ? 'Draft'
        : (REVIEW_LABEL[github.reviewDecision ?? ''] ?? 'Open')
      : github.state.charAt(0) + github.state.slice(1).toLowerCase()

  return `${state} on GitHub · checked ${relativeTime(github.checkedAt, now)}`
}

export function relativeTime(timestamp: string, now = Date.now()) {
  const minutes = Math.max(0, Math.round((now - Date.parse(timestamp)) / 60000))
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
