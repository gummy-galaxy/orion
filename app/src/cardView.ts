import type { SourceRef } from './derive'
import {
  getPullReadiness,
  getPullRef,
  getTaskTag,
  getTaskUrl,
  READINESS_LABEL,
  STATUS_LABEL,
  type CheckCounts,
  type ItemKind,
  type PullDetails,
  type PullReadiness,
  type TaskNode,
  type ViewStatus,
  type Who,
} from './model'
import { getRarity, type Rarity } from './rarity'
import { repoOfPullKey, withSnoozes, type CheckSnooze } from './checkSnoozes'

export type CardView = {
  id: string
  /** 'step' | 'pr' | 'placeholder' | 'gate' | 'note', from data.itemKind */
  kind: ItemKind
  title: string
  tag: string
  url: string | null
  /** GitHub pull request URL for opening the card's work in an editor. */
  pullRequestUrl?: string
  status: ViewStatus
  statusLabel: string
  who?: Who
  whoLabel?: string
  leverage: number
  upstream: number
  rarity?: Rarity
  checks?: 'passing' | 'failing' | 'pending'
  /** How close an open pull request is to merging. */
  readiness?: PullReadiness
  /** Whether an open pull request's unfinished checks have started, even when one has already failed. */
  checkProgress?: 'running' | 'waiting'
  /** How many of an open pull request's checks have finished and failed, out of all of them. */
  checkCounts?: CheckCounts
  /** GitHub would merge the pull request now, and the card isn't parked or blocked by hand. */
  readyToMerge?: true
  /** The pull request and head commit a merge from the card must match, while it's ready to merge. */
  merge?: { url: string; head: string }
  sources: SourceRef[]
  note?: string
  repo?: string
  /** Stable seed for procedural art: the card id. */
  artSeed: string
  /** Direct predecessors that are still open. */
  blockers?: number
  /** Direct successors that are still open. */
  unblocks?: number
  /** The group the card sits in. */
  group?: string
  /** The pull request's review asks for changes. */
  changesRequested?: true
  /** When the pull request last changed. */
  updatedAt?: string
  /** Priority set by a source, from 0 (most urgent) to 3. No source sets one yet. */
  priority?: Priority
  /** Size set by a source. No source sets one yet. */
  size?: CardSizeLabel
}

export type Priority = 0 | 1 | 2 | 3
export type CardSizeLabel = 'S' | 'M' | 'L' | 'XL'

const WHO_LABEL: Record<Who, string> = { you: 'Your move', review: 'Waiting on review', ci: 'Waiting on CI' }

function getChecks(checks: PullDetails['checks'] | undefined): CardView['checks'] {
  switch (checks) {
    case 'SUCCESS':
      return 'passing'
    case 'FAILURE':
    case 'ERROR':
      return 'failing'
    case 'PENDING':
    case 'EXPECTED':
      return 'pending'
    default:
      return undefined
  }
}

export type CardFacts = {
  status: ViewStatus
  leverage: number
  upstream: number
  sources: SourceRef[]
  blockers?: number
  unblocks?: number
  group?: string
  /** CI jobs the canvas has snoozed, left out of whether the card's checks are failing. */
  snoozes?: CheckSnooze[]
}

export function getCardView(node: TaskNode, facts: CardFacts): CardView {
  const { data } = node
  const who = facts.status === 'done' ? undefined : data.who
  const pullRef = getPullRef(data)
  const recorded = pullRef?.details as PullDetails | undefined
  const pullDetails = recorded && pullRef ? withSnoozes(recorded, repoOfPullKey(pullRef.key), node.id, facts.snoozes ?? []) : recorded
  const checks = getChecks(pullDetails?.checks)
  const readiness = getPullReadiness(pullDetails)
  const open = pullDetails?.state === 'OPEN'
  const checkProgress = open ? pullDetails.checkProgress : undefined
  const checkCounts = open ? pullDetails.checkCounts : undefined
  // Work parked or blocked by hand stays that way even when GitHub would merge it.
  const readyToMerge = readiness === 'mergeable' && (facts.status === 'review' || facts.status === 'ready' || facts.status === 'active')
  const merge = readyToMerge && pullRef?.url && pullDetails?.head ? { url: pullRef.url, head: pullDetails.head } : undefined
  // The primary ref's URL, so a badge for another GitHub ref can't change what opens from a pull request card.
  const url = getTaskUrl(data)
  const pullRequestUrl = data.itemKind === 'pr' && url?.startsWith('https://github.com/') ? url : undefined

  return {
    id: node.id,
    kind: data.itemKind,
    title: data.label,
    tag: getTaskTag(data),
    url,
    ...(pullRequestUrl ? { pullRequestUrl } : {}),
    status: facts.status,
    statusLabel: readyToMerge ? READINESS_LABEL.mergeable : STATUS_LABEL[facts.status],
    ...(who ? { who, whoLabel: WHO_LABEL[who] } : {}),
    leverage: facts.leverage,
    upstream: facts.upstream,
    ...(data.itemKind === 'note' ? {} : { rarity: getRarity(facts.upstream) }),
    ...(checks ? { checks } : {}),
    ...(readiness ? { readiness } : {}),
    ...(checkProgress ? { checkProgress } : {}),
    ...(checkCounts ? { checkCounts } : {}),
    ...(readyToMerge ? { readyToMerge } : {}),
    ...(merge ? { merge } : {}),
    sources: facts.sources,
    note: data.note,
    repo: data.repo,
    artSeed: node.id,
    ...(facts.blockers !== undefined ? { blockers: facts.blockers } : {}),
    ...(facts.unblocks !== undefined ? { unblocks: facts.unblocks } : {}),
    ...(facts.group ? { group: facts.group } : {}),
    ...(pullDetails?.reviewDecision === 'CHANGES_REQUESTED' ? { changesRequested: true as const } : {}),
    ...(pullDetails?.updatedAt ? { updatedAt: pullDetails.updatedAt } : {}),
  }
}
