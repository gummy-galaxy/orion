import type { FailedCheck, PullReadiness, RefChecks, SourceRef } from './model'

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

/** The jobs that failed on a pull request ref, as the CLI records them with its GitHub details. */
export function readFailedChecks(details: Record<string, unknown> | undefined): FailedCheck[] {
  const raw = details?.failedChecks

  if (!Array.isArray(raw)) return []

  return raw.filter((entry): entry is FailedCheck => !!entry && typeof entry === 'object' && typeof entry.name === 'string')
}

/**
 * A pull request ref with snoozed jobs left out of its checks and readiness, so a card whose only failures are snoozed
 * reads as running or passing. Optional failures are already left out of the counts the CLI records.
 */
export function withSnoozes(ref: SourceRef, cardId: string, snoozes: CheckSnooze[], now = Date.now()): SourceRef {
  const repo = repoOfPullKey(ref.key)
  const failedChecks = readFailedChecks(ref.details)

  if (!repo || !snoozes.length || !failedChecks.length || ref.checks?.state !== 'failing') return ref

  const counted = failedChecks.filter((check) => !check.optional)
  const snoozed = counted.filter((check) => isSnoozedOn(snoozes, repo, check.name, cardId, now)).length

  if (!snoozed) return ref

  const { total, finished } = ref.checks
  const failed = ref.checks.failed !== undefined ? Math.max(0, ref.checks.failed - snoozed) : counted.length - snoozed
  const counts = ref.checks.failed !== undefined ? { failed } : {}

  if (failed > 0) return { ...ref, checks: { ...ref.checks, ...counts } }

  const running = total !== undefined && finished !== undefined && finished < total
  const checks: RefChecks = { ...ref.checks, ...counts, state: running ? 'pending' : 'passing' }
  // Readiness follows the checks the way orion serve derives it, and a conflict still comes first.
  const readiness: PullReadiness | undefined =
    ref.readiness === 'failing' ? (running ? (ref.checks.progress === 'waiting' ? 'waiting' : 'running') : 'passing') : ref.readiness

  return { ...ref, checks, ...(readiness ? { readiness } : {}) }
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
