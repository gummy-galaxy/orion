/** Who wrote a log entry: the person running the CLI, or an agent they named. */
export type LogAuthor = { kind: 'person' | 'agent'; name: string }

/** One line of the canvas log. Entries are only appended, so a correction is a new entry. */
export type LogEntry = {
  id: string
  text: string
  time: string
  author: LogAuthor
  targets: { kind: 'card'; id: string }[]
}

const API = '/api/log'

const isLogEntry = (value: unknown): value is LogEntry => {
  const entry = value as Partial<LogEntry> | null

  return (
    !!entry &&
    typeof entry.id === 'string' &&
    typeof entry.text === 'string' &&
    typeof entry.time === 'string' &&
    typeof entry.author?.name === 'string' &&
    Array.isArray(entry.targets)
  )
}

/**
 * The canvas log, oldest first, as `orion serve` answers it. Null when there is no log to show:
 * an older server that doesn't serve it (404), or a static build that answers with its page.
 */
export async function fetchLog(workspace: string): Promise<LogEntry[] | null> {
  try {
    const response = await fetch(`${API}?workspace=${encodeURIComponent(workspace)}`)

    if (!response.ok || !response.headers.get('content-type')?.includes('json')) return null

    const body = (await response.json()) as { entries?: unknown }

    return Array.isArray(body.entries) ? body.entries.filter(isLogEntry) : null
  } catch {
    return null
  }
}

/** The entries attached to one card, newest first. Entries that name several cards show under each of them. */
export function getCardLog(entries: LogEntry[], cardId: string): LogEntry[] {
  return entries.filter((entry) => entry.targets.some((target) => target.id === cardId)).reverse()
}
