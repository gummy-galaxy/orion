import { findCardType } from './cardTypes/findCardType'
import { formatFieldValue } from './cardTypes/formatFieldValue'
import { getCardType } from './cardTypes/getCardType'
import { getFieldValues } from './cardTypes/getFieldValues'
import { getItemTypes } from './cardTypes/getItemTypes'
import type { CardType, Face } from './cardTypes/types'
import type { SnoozedFacts, SourceRef } from './derive'
import {
  getCheckCounts,
  getPullRef,
  getTaskTag,
  getTaskUrl,
  READINESS_LABEL,
  STATUS_LABEL,
  type CheckCounts,
  type PullReadiness,
  type TaskData,
  type TaskNode,
  type ViewStatus,
  type Who,
} from './model'
import type { Rarity } from './rarity'
import { withSnoozedFacts } from './withSnoozedFacts'

export type CardView = {
  id: string
  /** The card's primary type, such as `step`, `pr`, `gate`, `note`, or one a source declares. */
  kind: string
  /** Which face draws the card, from its primary type. */
  layout: Face['layout']
  /** The fields the primary type shows on the face, in order, with the ones that have no value left out. */
  fields: { name: string; label: string; text: string }[]
  /** Types people attached beyond the card's own, by label. */
  badges: string[]
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

export type CardFacts = {
  status: ViewStatus
  leverage: number
  upstream: number
  rarity?: Rarity
  sources: SourceRef[]
  blockers?: number
  unblocks?: number
  group?: string
  /** The card's pull request facts with its snoozed CI jobs left out, when a snooze leaves one out. */
  snoozedFacts?: SnoozedFacts
}

/** The fields a card's primary type shows on its face, formatted, skipping any without a value. */
function getFaceFields(data: TaskData, cardType: CardType): CardView['fields'] {
  const values = getFieldValues(data)

  return cardType.face.shows.flatMap((name) => {
    const entry = values.find((candidate) => candidate.field.name === name)
    const text = entry && formatFieldValue(entry.field, entry.value)

    return entry && text ? [{ name, label: entry.field.label, text }] : []
  })
}

export function getCardView(node: TaskNode, facts: CardFacts): CardView {
  const { data } = node
  const who = facts.status === 'done' ? undefined : data.who
  const recorded = getPullRef(data)
  const pullRef = recorded && withSnoozedFacts(recorded, facts.snoozedFacts)
  const checks = pullRef?.checks?.state
  const readiness = pullRef?.readiness
  const checkProgress = pullRef?.checks?.progress
  const checkCounts = getCheckCounts(pullRef?.checks)
  // Work parked or blocked by hand stays that way even when GitHub would merge it.
  const readyToMerge = readiness === 'mergeable' && (facts.status === 'review' || facts.status === 'ready' || facts.status === 'active')
  const merge = readyToMerge && pullRef?.url && pullRef.head ? { url: pullRef.url, head: pullRef.head } : undefined
  // The primary ref's URL, so a badge for another GitHub ref can't change what opens from a pull request card.
  const url = getTaskUrl(data)
  const cardType = getCardType(data)
  // The type's own word for its state, unless the graph says something else, such as blocked or ready.
  const recordedState = cardType.states.find((state) => state.name === data.status && state.means === facts.status)
  const pullRequestUrl = cardType.name === 'pr' && url?.startsWith('https://github.com/') ? url : undefined

  return {
    id: node.id,
    kind: getItemTypes(data).primary,
    layout: cardType.face.layout,
    fields: getFaceFields(data, cardType),
    badges: (data.types ?? []).map((name) => findCardType(name)?.label ?? name),
    title: data.label,
    tag: getTaskTag(data),
    url,
    ...(pullRequestUrl ? { pullRequestUrl } : {}),
    status: facts.status,
    statusLabel: readyToMerge ? READINESS_LABEL.mergeable : (recordedState?.label ?? STATUS_LABEL[facts.status]),
    ...(who ? { who, whoLabel: WHO_LABEL[who] } : {}),
    leverage: facts.leverage,
    upstream: facts.upstream,
    // Only work has a rarity, so notes and components show none.
    ...(cardType.meaning.isWork ? { rarity: facts.rarity ?? 'common' } : {}),
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
    ...(pullRef?.changesRequested ? { changesRequested: true as const } : {}),
    ...(pullRef?.updatedAt ? { updatedAt: pullRef.updatedAt } : {}),
  }
}
