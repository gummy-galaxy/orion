import type { SourceRef } from './derive'
import { getPullRef, getTaskTag, getTaskUrl, STATUS_LABEL, type ItemKind, type PullDetails, type TaskNode, type ViewStatus, type Who } from './model'

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
  checks?: 'passing' | 'failing' | 'pending'
  sources: SourceRef[]
  note?: string
  repo?: string
  /** Stable seed for procedural art: the card id. */
  artSeed: string
}

const WHO_LABEL: Record<Who, string> = { you: 'Your move', review: 'Waiting on review', ci: 'Waiting on CI' }

function getChecks(data: TaskNode['data']): CardView['checks'] {
  const checks = (getPullRef(data)?.details as PullDetails | undefined)?.checks

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

export function getCardView(node: TaskNode, facts: { status: ViewStatus; leverage: number; sources: SourceRef[] }): CardView {
  const { data } = node
  const who = facts.status === 'done' ? undefined : data.who
  const checks = getChecks(data)
  const pullRequestUrl = data.itemKind === 'pr' ? facts.sources.find((source) => source.href?.startsWith('https://github.com/'))?.href : undefined

  return {
    id: node.id,
    kind: data.itemKind,
    title: data.label,
    tag: getTaskTag(data),
    url: getTaskUrl(data),
    ...(pullRequestUrl ? { pullRequestUrl } : {}),
    status: facts.status,
    statusLabel: STATUS_LABEL[facts.status],
    ...(who ? { who, whoLabel: WHO_LABEL[who] } : {}),
    leverage: facts.leverage,
    ...(checks ? { checks } : {}),
    sources: facts.sources,
    note: data.note,
    repo: data.repo,
    artSeed: node.id,
  }
}
