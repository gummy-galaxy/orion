import type { Node } from '@xyflow/react'
import { taskHeight } from './cardHeight'
import type { CardSize } from './cardSize'

export const TASK_WIDTH = 216
export const TASK_HEIGHT = 72
export const GROUP_PADDING = 32
export const GROUP_HEADER_HEIGHT = 78
/** The band a group's Markdown header takes under its title row, which pushes its cards down by the same amount. */
export const GROUP_HEADER_BAND = 112

/** `blocked` is set by hand for blockers outside the graph; dependency blocking is derived. */
export type Status = 'todo' | 'active' | 'review' | 'blocked' | 'deferred' | 'done'
export type Who = 'you' | 'review' | 'ci'
export type ViewStatus = 'ready' | 'active' | 'review' | 'blocked' | 'deferred' | 'done'
/**
 * A pull request that exists, one that is expected but not opened yet, a step with no
 * pull request, a gate, a note, or a component. A gate is done once everything it waits on is,
 * like a milestone or sign-off. Notes and components aren't work: they pass blocking through.
 * A component is a part of a system diagram, like a service or a data store, and has no status.
 */
export type ItemKind = 'pr' | 'placeholder' | 'step' | 'gate' | 'note' | 'component'

/**
 * How a component is drawn: a box for a service (the default), a cylinder for a data store, a pill for a person
 * or agent, a dashed box for something outside the system, a window for a user interface, a chevron for a job or
 * command, and a stack for a stream of events.
 */
export type ComponentShape = 'service' | 'store' | 'actor' | 'external' | 'interface' | 'process' | 'queue'
export const COMPONENT_SHAPES: ComponentShape[] = ['service', 'store', 'actor', 'external', 'interface', 'process', 'queue']
export const SHAPE_LABEL: Record<ComponentShape, string> = {
  service: 'Service',
  store: 'Store',
  actor: 'Actor',
  external: 'External',
  interface: 'Interface',
  process: 'Process',
  queue: 'Queue',
}
/** Tints a group's frame and the components inside it that don't set their own. */
export type Tint = 'teal' | 'blue' | 'purple' | 'amber' | 'rose' | 'green' | 'slate'
export const TINTS: Tint[] = ['teal', 'blue', 'purple', 'amber', 'rose', 'green', 'slate']

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
  /** Components only. */
  shape?: ComponentShape
  /** Components only; otherwise the nearest group's tint applies. */
  color?: Tint
  /** UTC time a snooze ends, in the form the CLI stores. Snoozed work is set aside until then. */
  snoozedUntil?: string
  /**
   * True while a card finished outside the app waits to be closed out. The CLI store sets it on every path that
   * finishes a card and clears it on reopen. The app sends false when it finishes a card itself, so the store
   * closes it out at once and drops the flag.
   */
  celebrate?: boolean
}
/**
 * Outside work a card carries. The source's adapter in the CLI reads the source and fills in the source-neutral facts
 * below, so the app shows them as they are. `details` is the source's own record, which only its adapter reads.
 */
export type SourceRef = {
  source: string
  kind: string
  key: string
  url?: string
  status?: string
  isDone?: boolean
  updatedAt?: string
  /** When the adapter last read the source. */
  checkedAt?: string
  /** The source's word for the ref's state, with its name, such as "Approved on GitHub". */
  stateLabel?: string
  /** How close open work is to landing. */
  readiness?: PullReadiness
  checks?: RefChecks
  changesRequested?: boolean
  author?: string
  isMine?: boolean
  isReviewRequested?: boolean
  additions?: number
  deletions?: number
  /** The revision the facts describe, which a merge from the card must still match. */
  head?: string
  /** An agent session's state, working, waiting, or done, and the last thing it said. */
  sessionState?: string
  lastMessage?: string
  details?: Record<string, unknown>
}
/** A ref's checks. Progress and counts describe checks still to come, so they're only there while the work is open. */
export type RefChecks = {
  state: 'passing' | 'failing' | 'pending'
  /** Whether any unfinished check has started, or all of them are still queued. */
  progress?: 'running' | 'waiting'
  total?: number
  finished?: number
  failed?: number
  /** The jobs that failed, by name, while the work is open. */
  failures?: FailedCheck[]
}
/** A commit's checks: how many have finished, and failed, out of all of them. Skipped and cancelled checks count as finished. */
export type CheckCounts = { total: number; finished: number; failed: number }
/** A CI job that failed on a pull request, by the name GitHub shows for it. */
export type FailedCheck = { name: string; optional?: boolean }

/** A ref's check counts, when its source reported all three. */
export function getCheckCounts(checks: RefChecks | undefined): CheckCounts | undefined {
  if (checks?.total === undefined || checks.finished === undefined || checks.failed === undefined) return undefined

  return { total: checks.total, finished: checks.finished, failed: checks.failed }
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

/** "5 of 8 done, 1 failed" while checks run, "1 of 8 failed" once they finish, and nothing once they all pass. */
export function getCheckCountsLabel(counts: CheckCounts): string | undefined {
  const failed = counts.failed > 0 ? `${counts.failed} failed` : undefined

  if (counts.finished < counts.total) return [`${counts.finished} of ${counts.total} done`, failed].filter(Boolean).join(', ')

  return failed && `${counts.failed} of ${counts.total} failed`
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
  color?: Tint
  /** An image asset id from this workspace's assets, shown as a banner across the top of the group. */
  cover?: string
  /** A hex color, a color token name such as `card.background`, or an image asset id. */
  background?: string
  /** Markdown with a sanitized subset of HTML for layout, shown in a band under the group's title. */
  header?: string
  /**
   * The size a person gave the group by dragging its edges. An automatic group lays its contents out to fit this
   * width and hugs them. A custom group stays at least this big, growing only to hold what's inside. Without it, a
   * group hugs what's inside.
   */
  size?: { width: number; height: number }
}
export type ImageData = { kind: 'image'; label: string; asset: string; workspace: string }
export type TaskNode = Node<TaskData, 'task'>
/** Stand-in for work outside the opened group that links into it. Never stored. Components have no status. */
export type GhostData = { kind: 'ghost'; taskId: string; label: string; where: string; status?: ViewStatus; side: 'in' | 'out' }
export type GhostNode = Node<GhostData, 'ghost'>
export type ClusterNode = Node<ClusterData, 'cluster'>
export type ImageNode = Node<ImageData, 'image'>
export type AppNode = TaskNode | ClusterNode | ImageNode

/**
 * `origin` marks links Orion derived itself: stacked pull requests, or a reference in a title, body or branch.
 * `label` names what the link carries, like "HTTP" between two components.
 */
export type Link = { id: string; from: string; to: string; kind: 'blocks' | 'related'; origin?: 'stack' | 'mention'; label?: string }

export const STATUS_LABEL: Record<ViewStatus, string> = {
  ready: 'Ready',
  active: 'In progress',
  review: 'In review',
  blocked: 'Blocked',
  deferred: 'Deferred',
  done: 'Done',
}

/** The statuses a person can record on a card, in the order the inspector lists them. */
export const STATUS_CHOICES: { value: Status; label: string }[] = [
  { value: 'todo', label: 'To do' },
  { value: 'active', label: 'In progress' },
  { value: 'review', label: 'In review' },
  { value: 'blocked', label: 'Blocked' },
  { value: 'deferred', label: 'Deferred' },
  { value: 'done', label: 'Done' },
]

export const WHO_CHOICES: { value: Who; label: string }[] = [
  { value: 'you', label: 'You' },
  { value: 'review', label: 'Reviewer' },
  { value: 'ci', label: 'CI' },
]

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

/** A card's kind from its repository and pull request. Gates, notes, and components keep their kind. */
export function getItemKind(data: Pick<TaskData, 'itemKind' | 'repo' | 'refs'>): ItemKind {
  if (data.itemKind === 'gate' || data.itemKind === 'note' || data.itemKind === 'component') return data.itemKind

  return getPullRef(data) ? 'pr' : data.repo ? 'placeholder' : 'step'
}

export function getTaskTag(data: TaskData): string {
  return getPrimaryRef(data)?.key ?? data.repo ?? (data.itemKind === 'gate' || data.itemKind === 'component' ? data.itemKind : 'step')
}

export function getTaskUrl(data: TaskData): string | null {
  return getPrimaryRef(data)?.url ?? null
}

export const isCluster = (node: AppNode): node is ClusterNode => node.type === 'cluster'
export const isTask = (node: AppNode): node is TaskNode => node.type === 'task'
export const isImage = (node: AppNode): node is ImageNode => node.type === 'image'
export const isNote = (node: AppNode | undefined): boolean => !!node && isTask(node) && node.data.itemKind === 'note'
export const isComponent = (node: AppNode | undefined): boolean => !!node && isTask(node) && node.data.itemKind === 'component'
/** Cards that count as work. Notes and components pass blocking through and never do. */
export const isWork = (node: AppNode | undefined): boolean => !!node && isTask(node) && !isNote(node) && !isComponent(node)

/** A card's label for lists and links, with notes falling back to the word Note. */
export const cardLabel = (node: AppNode): string => (node.data as TaskData).label || (isComponent(node) ? 'Untitled component' : 'Note')

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

/**
 * The group to show once the nodes change from `before` to `after`: the open group while it's still there, or else its
 * nearest ancestor that is, or null for the top level.
 */
export function survivingRoot(root: string, before: Map<string, AppNode>, after: Map<string, AppNode>): string | null {
  const isGroup = (id: string) => {
    const node = after.get(id)

    return !!node && isCluster(node)
  }

  if (isGroup(root)) return root

  return ancestors(root, before).find(isGroup) ?? null
}

/** A component's own tint, or else its nearest group's. Work cards and notes have none. */
export function tintOf(node: AppNode, nodeMap: Map<string, AppNode>): Tint | undefined {
  if (isTask(node) && node.data.itemKind !== 'component') return undefined

  if (!isImage(node) && node.data.color) return node.data.color

  for (const ancestor of ancestors(node.id, nodeMap)) {
    const color = (nodeMap.get(ancestor)?.data as ClusterData | undefined)?.color

    if (color) return color
  }

  return undefined
}

export function sizeOf(node: AppNode, cardSize: CardSize = { width: TASK_WIDTH, height: TASK_HEIGHT }): CardSize {
  if (isTask(node)) return { width: cardSize.width, height: taskHeight(node.data, cardSize) }

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
  if (isTask(node)) return { ...node, ...sizeOf(node, cardSize) }

  if (isImage(node)) return { ...node, width: node.width ?? 256, height: node.height ?? 256 }

  return { ...node, dragHandle: '.drag' }
}

/** React Flow needs parents before children. */
function sortNodes(nodes: AppNode[]): AppNode[] {
  const nodeMap = byId(nodes)

  return [...nodes].sort((a, b) => ancestors(a.id, nodeMap).length - ancestors(b.id, nodeMap).length)
}

/**
 * Shrinks or grows every group to hug its children, deepest first. A group with nothing inside keeps its place and
 * takes the smallest size that fits one card, so an empty group made on purpose, such as by `orion group create`,
 * stays on the canvas. Children keep their place on screen. A custom group with a size keeps its corner and stays at
 * least that big, and when its children reach past it, it grows and remembers the larger size.
 */
function fitGroups(nodes: AppNode[], cardSize: CardSize): AppNode[] {
  const nodeMap = new Map(nodes.map((node) => [node.id, { ...node } as AppNode]))
  const depth = (id: string) => ancestors(id, nodeMap).length
  const clusters = [...nodeMap.values()].filter(isCluster).sort((a, b) => depth(b.id) - depth(a.id))

  for (const group of clusters) {
    const data = group.data as ClusterData
    const floor = data.arrange === 'custom' ? data.size : undefined
    const children = [...nodeMap.values()].filter((node) => node.parentId === group.id)

    if (!children.length) {
      group.width = Math.max(cardSize.width + GROUP_PADDING * 2, floor?.width ?? 0)
      group.height = Math.max(cardSize.height + GROUP_HEADER_HEIGHT + GROUP_PADDING, floor?.height ?? 0)
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

    const headerHeight = groupHeaderHeight(data)
    let left = minX - GROUP_PADDING
    let top = minY - headerHeight
    let right = maxX + GROUP_PADDING
    let bottom = maxY + GROUP_PADDING

    if (floor) {
      left = Math.min(left, 0)
      top = Math.min(top, 0)
      right = Math.max(right, floor.width)
      bottom = Math.max(bottom, floor.height)
    }

    for (const child of children) child.position = { x: child.position.x - left, y: child.position.y - top }

    group.position = { x: group.position.x + left, y: group.position.y + top }
    group.width = right - left
    group.height = bottom - top

    // Remembering the size it grew to keeps the next fit from shrinking it back. Rounding noise isn't growth.
    if (floor && (Math.abs(floor.width - group.width) > 0.5 || Math.abs(floor.height - group.height) > 0.5))
      group.data = { ...data, size: { width: group.width, height: group.height } }
  }

  return [...nodeMap.values()]
}

/** The height above a group's cards: the title row, plus the header band when the group has a header. */
export function groupHeaderHeight(data: { header?: string } | undefined): number {
  return GROUP_HEADER_HEIGHT + (data?.header?.trim() ? GROUP_HEADER_BAND : 0)
}

export function normalize(nodes: AppNode[], cardSize: CardSize = { width: TASK_WIDTH, height: TASK_HEIGHT }): AppNode[] {
  return sortNodes(fitGroups(nodes, cardSize)).map((node) => hydrate(node, cardSize))
}

/**
 * Removes the groups that `after` left with nothing inside, but only those that `before` had children in. An edit
 * removes a group this way when it takes the group's last child out; a group that was already empty stays, and so
 * does one the edit didn't touch. A group that goes can leave its own parent empty, so that goes too.
 */
export function pruneEmptied(before: AppNode[], after: AppNode[]): AppNode[] {
  const hadChildren = new Set(before.map((node) => node.parentId).filter((id): id is string => !!id))
  let next = after

  for (;;) {
    const haveChildren = new Set(next.map((node) => node.parentId).filter((id): id is string => !!id))
    const emptied = new Set(next.filter((node) => isCluster(node) && hadChildren.has(node.id) && !haveChildren.has(node.id)).map((node) => node.id))

    if (!emptied.size) return next

    next = next.filter((node) => !emptied.has(node.id))
  }
}

/** Removes nodes from the canvas, dropping any group they were the last of. */
export function removeNodes(nodes: AppNode[], ids: string[], cardSize: CardSize = { width: TASK_WIDTH, height: TASK_HEIGHT }): AppNode[] {
  const removed = new Set(ids)

  return pruneEmptied(
    nodes,
    normalize(
      nodes.filter((node) => !removed.has(node.id)),
      cardSize,
    ),
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

/** "Merged on GitHub · checked 2h ago" for a ref its adapter has read. */
export function getRefSummary(ref: SourceRef, now = Date.now()): string | undefined {
  if (!ref.stateLabel) return undefined

  return ref.checkedAt ? `${ref.stateLabel} · checked ${relativeTime(ref.checkedAt, now)}` : ref.stateLabel
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
