import type { PullDetails } from './model'

/**
 * A CI job whose failures cards leave out, for every card in its repository. With `until`, the snooze ends at that
 * time; without it, it lasts on each card until the job passes there, and `passed` lists the cards where it has.
 */
export type CheckSnooze = { repo: string; name: string; until?: string; at: string; passed?: string[] }

/** How long a new snooze lasts: until the job next passes on each card, or for a while. */
export const SNOOZE_LENGTHS = [
  { id: 'pass', label: 'Until it passes', ms: undefined },
  { id: 'hour', label: 'For an hour', ms: 60 * 60 * 1000 },
  { id: 'day', label: 'For a day', ms: 24 * 60 * 60 * 1000 },
  { id: 'week', label: 'For a week', ms: 7 * 24 * 60 * 60 * 1000 },
] as const

export type SnoozeLength = (typeof SNOOZE_LENGTHS)[number]['id']

/** The snoozes a canvas's settings hold, skipping any entry that isn't shaped like one. */
export function readCheckSnoozes(settings: Record<string, unknown> | undefined): CheckSnooze[] {
  const raw = settings?.checkSnoozes

  if (!Array.isArray(raw)) return []

  return raw.filter(
    (entry): entry is CheckSnooze =>
      !!entry && typeof entry === 'object' && typeof entry.repo === 'string' && typeof entry.name === 'string' && typeof entry.at === 'string',
  )
}

/** The `owner/name` a pull request key such as `owner/name#12`, or `host/owner/name#12`, belongs to. */
export function repoOfPullKey(key: string): string | undefined {
  return key.match(/([^/]+\/[^/#]+)#\d+$/)?.[1]
}

/** The snooze for a job in a repository, if one is still running. */
export function findSnooze(snoozes: CheckSnooze[], repo: string, name: string, now = Date.now()): CheckSnooze | undefined {
  return snoozes.find(
    (snooze) => snooze.repo.toLowerCase() === repo.toLowerCase() && snooze.name === name && (!snooze.until || Date.parse(snooze.until) > now),
  )
}

/** Whether a card leaves a job's failure out: a snooze covers it, and the job hasn't passed on the card since. */
export function isSnoozedOn(snoozes: CheckSnooze[], repo: string, name: string, cardId: string, now = Date.now()): boolean {
  const snooze = findSnooze(snoozes, repo, name, now)

  return !!snooze && (!!snooze.until || !snooze.passed?.includes(cardId))
}

/**
 * A pull request's details with snoozed jobs left out, so a card whose only failures are snoozed reads as running or
 * passing. Optional failures are already left out of the counts the CLI records.
 */
export function withSnoozes(details: PullDetails, repo: string | undefined, cardId: string, snoozes: CheckSnooze[], now = Date.now()): PullDetails {
  if (!repo || !snoozes.length || !details.failedChecks || (details.checks !== 'FAILURE' && details.checks !== 'ERROR')) return details

  const counted = details.failedChecks.filter((check) => !check.optional)
  const snoozed = counted.filter((check) => isSnoozedOn(snoozes, repo, check.name, cardId, now)).length

  if (!snoozed) return details

  const counts = details.checkCounts
  const failed = counts ? Math.max(0, counts.failed - snoozed) : counted.length - snoozed
  const checkCounts = counts ? { ...counts, failed } : undefined

  if (failed > 0) return { ...details, checkCounts }

  const running = counts ? counts.finished < counts.total : false

  return { ...details, checks: running ? 'PENDING' : 'SUCCESS', checkCounts }
}

/**
 * The snoozes after snoozing or unsnoozing a job, and when a new snooze ends. Snoozing a job again replaces its old
 * snooze, as the server does.
 */
export function changeSnoozes(
  snoozes: CheckSnooze[],
  change: { repo: string; name: string; snoozed: boolean; length: SnoozeLength },
  now = Date.now(),
): { snoozes: CheckSnooze[]; until?: string } {
  const ms = SNOOZE_LENGTHS.find((option) => option.id === change.length)?.ms
  const until = change.snoozed && ms ? new Date(now + ms).toISOString() : undefined
  const others = snoozes.filter((snooze) => !(snooze.repo.toLowerCase() === change.repo.toLowerCase() && snooze.name === change.name))

  if (!change.snoozed) return { snoozes: others }

  const added: CheckSnooze = { repo: change.repo, name: change.name, at: new Date(now).toISOString(), ...(until ? { until } : {}) }

  return { snoozes: [...others, added], ...(until ? { until } : {}) }
}
