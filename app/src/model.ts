import type { Node } from '@xyflow/react'
import type { CardSize } from './cardSize'

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
  /** Full owner/name of the repository this work belongs to. */
  repo?: string
  refs?: SourceRef[]
  note?: string
  who?: Who
}
export type SourceRef = {
  source: string
  kind: string
  key: string
  url?: string
  status?: string
  isDone?: boolean
  updatedAt?: string
  details?: Record<string, unknown>
}
export type PullDetails = {
  state: 'OPEN' | 'MERGED' | 'CLOSED'
  draft: boolean
  reviewDecision?: 'APPROVED' | 'CHANGES_REQUESTED' | 'REVIEW_REQUIRED'
  title: string
  author: string
  mine: boolean
  requestedFromYou: boolean
  updatedAt: string
  additions: number
  deletions: number
  checks?: 'SUCCESS' | 'FAILURE' | 'ERROR' | 'PENDING' | 'EXPECTED'
  /** Whether any unfinished check has started, or all of them are still queued. */
  checkProgress?: 'running' | 'waiting'
  mergeable?: 'MERGEABLE' | 'CONFLICTING' | 'UNKNOWN'
  mergeState?: 'BEHIND' | 'BLOCKED' | 'CLEAN' | 'DIRTY' | 'DRAFT' | 'HAS_HOOKS' | 'UNKNOWN' | 'UNSTABLE'
  /** The head commit the details describe, which a merge from the card must still match. */
  head?: string
  checkedAt: string
  branch?: string
}
/** How close an open pull request is to merging, from what stops it to nothing at all. */
export type PullReadiness = 'conflict' | 'failing' | 'running' | 'waiting' | 'passing' | 'mergeable'

export const READINESS_LABEL: Record<PullReadiness, string> = {
  conflict: 'Merge conflicts',
  failing: 'Checks failing',
  running: 'Checks running',
  waiting: 'Checks queued',
  passing: 'Checks passing',
  mergeable: 'Ready to merge',
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

export function getPrimaryRef(data: Pick<TaskData, 'refs'>): SourceRef | undefined {
  return data.refs?.find((ref) => ref.url) ?? data.refs?.[0]
}

export function getPullRef(data: Pick<TaskData, 'refs'>): SourceRef | undefined {
  return data.refs?.find((ref) => ref.kind === 'pull')
}

export function getPullRequestNumber(ref: SourceRef | undefined): number | undefined {
  if (ref?.kind !== 'pull') return undefined

  const number = Number(ref.key.match(/#([1-9]\d*)$/)?.[1])

  return Number.isSafeInteger(number) && number > 0 ? number : undefined
}

export function editPullRef(data: TaskData, repo: string | undefined, number: number | undefined): Pick<TaskData, 'repo' | 'refs' | 'itemKind'> {
  const repository = repo?.trim()
  const key = repository && number ? `${repository}#${number}` : undefined
  const existingPullRef = getPullRef(data)
  const remainingRefs = data.refs?.filter((ref) => ref.kind !== 'pull') ?? []
  const pullRef: SourceRef | undefined = key
    ? existingPullRef?.key.toLowerCase() === key.toLowerCase()
      ? existingPullRef
      : { source: 'github', kind: 'pull', key, url: `https://github.com/${repository}/pull/${number}` }
    : undefined
  const refs = [...(pullRef ? [pullRef] : []), ...remainingRefs]

  return { repo, refs: refs.length ? refs : undefined, itemKind: getItemKind({ ...data, repo, refs }) }
}

/** A card's kind from its repository and pull request. Gates and notes keep their kind. */
export function getItemKind(data: Pick<TaskData, 'itemKind' | 'repo' | 'refs'>): ItemKind {
  if (data.itemKind === 'gate' || data.itemKind === 'note') return data.itemKind

  return getPullRef(data) ? 'pr' : data.repo ? 'placeholder' : 'step'
}

export function getTaskTag(data: TaskData): string {
  return getPrimaryRef(data)?.key ?? data.repo ?? (data.itemKind === 'gate' ? 'gate' : 'step')
}

export function getTaskUrl(data: TaskData): string | null {
  return getPrimaryRef(data)?.url ?? null
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

export function sizeOf(node: AppNode, cardSize: CardSize = { width: TASK_WIDTH, height: TASK_HEIGHT }): CardSize {
  if (isTask(node)) return cardSize

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
function hydrate(node: AppNode, cardSize: CardSize): AppNode {
  if (isTask(node)) return { ...node, ...cardSize, expandParent: !!node.parentId }

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
function fitGroups(nodes: AppNode[], cardSize: CardSize): AppNode[] {
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
      const size = sizeOf(child, cardSize)

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

export function normalize(nodes: AppNode[], cardSize: CardSize = { width: TASK_WIDTH, height: TASK_HEIGHT }): AppNode[] {
  return sortNodes(fitGroups(nodes, cardSize)).map((node) => hydrate(node, cardSize))
}

/** Wraps the selection in a new group under the selection's nearest shared parent. */
export function groupSelection(
  nodes: AppNode[],
  cardSize: CardSize = { width: TASK_WIDTH, height: TASK_HEIGHT },
): { nodes: AppNode[]; groupId: string } | null {
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

  return { nodes: normalize([...next, group], cardSize), groupId }
}

/** Dissolves the given groups, handing their children to the group's parent in place. */
export function ungroup(nodes: AppNode[], ids: string[], cardSize: CardSize = { width: TASK_WIDTH, height: TASK_HEIGHT }): AppNode[] {
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

  return normalize(next, cardSize)
}

/** Gap between a moved group and the siblings it lands beside, matching `orion move` in the CLI. */
const ITEM_GAP = 48

/** The first spot at or below `preferred` that no sibling overlaps, so a moved group keeps its place when it's free. */
function freeSpotBelow(siblings: AppNode[], preferred: { x: number; y: number }, size: { width: number; height: number }, cardSize: CardSize) {
  const spot = { ...preferred }

  const clashes = (sibling: AppNode) => {
    const siblingSize = sizeOf(sibling, cardSize)

    return (
      spot.x < sibling.position.x + siblingSize.width &&
      sibling.position.x < spot.x + size.width &&
      spot.y < sibling.position.y + siblingSize.height &&
      sibling.position.y < spot.y + size.height
    )
  }

  let clash = siblings.find(clashes)

  while (clash) {
    spot.y = clash.position.y + sizeOf(clash, cardSize).height + ITEM_GAP
    clash = siblings.find(clashes)
  }

  return spot
}

/**
 * Lifts a group out of its parent to the parent's level, at the first free spot at or below where it was, so it stays
 * where it was on screen when nothing covers it. The parent shrinks or grows to fit what remains. Anything else returns
 * the nodes unchanged.
 */
export function moveOutOfGroup(nodes: AppNode[], id: string, cardSize: CardSize = { width: TASK_WIDTH, height: TASK_HEIGHT }): AppNode[] {
  const nodeMap = byId(nodes)
  const group = nodeMap.get(id)

  if (!group || !isCluster(group) || !group.parentId) return nodes

  const parent = nodeMap.get(group.parentId)
  const grandparent = parent?.parentId ? nodeMap.get(parent.parentId) : undefined
  const origin = grandparent ? absolutePosition(grandparent, nodeMap) : { x: 0, y: 0 }
  const absolute = absolutePosition(group, nodeMap)
  // Fitting first lets the old parent shrink to what remains, so the spot is checked against where it will actually be.
  const lifted = normalize(
    nodes.map((node) =>
      node.id === id ? { ...node, parentId: grandparent?.id, position: { x: absolute.x - origin.x, y: absolute.y - origin.y } } : node,
    ),
    cardSize,
  )
  const landed = lifted.find((node) => node.id === id)

  if (!landed) return lifted

  const siblings = lifted.filter((node) => node.parentId === landed.parentId && node.id !== id)
  const position = freeSpotBelow(siblings, landed.position, sizeOf(landed, cardSize), cardSize)

  return normalize(
    lifted.map((node) => (node.id === id ? { ...node, position } : node)),
    cardSize,
  )
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
export function getPullReadiness(details: PullDetails | undefined): PullReadiness | undefined {
  if (details?.state !== 'OPEN') return undefined

  if (details.mergeable === 'CONFLICTING' || details.mergeState === 'DIRTY') return 'conflict'

  if (details.checks === 'FAILURE' || details.checks === 'ERROR') return 'failing'

  if (details.checks === 'PENDING' || details.checks === 'EXPECTED') return details.checkProgress === 'waiting' ? 'waiting' : 'running'

  if (!details.draft && (details.mergeState === 'CLEAN' || details.mergeState === 'HAS_HOOKS')) return 'mergeable'

  return details.checks === 'SUCCESS' ? 'passing' : undefined
}

export function githubSummary(github: PullDetails, now = Date.now()) {
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
