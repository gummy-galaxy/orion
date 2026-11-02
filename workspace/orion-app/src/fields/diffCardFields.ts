import { getPullRef, getPullRequestNumber, type TaskData } from '../model'
import type { CardFields } from './types'

/** Fields copied as they are, with an empty string for one that was cleared. */
const PLAIN_FIELDS = ['label', 'status', 'who', 'note', 'repo', 'shape', 'color', 'snoozedUntil'] as const

/** Kinds a card is given, rather than taking from its repository and pull request. */
const GIVEN_KINDS = new Set(['gate', 'component', 'note'])

/**
 * The fields that turn a card's `before` data into `after`, for a setFields operation. The server works out the kind
 * from the repository and pull request, so a kind is sent only when one was given or taken away, and the server's
 * own fields, such as refs other than the pull request and the close-out flag, are left out.
 */
export function diffCardFields(before: TaskData, after: TaskData): CardFields {
  const fields: Record<string, unknown> = {}

  for (const key of PLAIN_FIELDS) {
    if (before[key] !== after[key]) fields[key] = after[key] ?? ''
  }

  if (before.type !== after.type) {
    if (after.type === 'gate' || after.type === 'component') fields.kind = after.type
    else if (after.type !== 'note' && GIVEN_KINDS.has(before.type)) fields.kind = 'step'
  }

  const pullRequest = getPullRequestNumber(getPullRef(after))

  if (getPullRequestNumber(getPullRef(before)) !== pullRequest) fields.pr = pullRequest ?? ''

  return fields as CardFields
}
