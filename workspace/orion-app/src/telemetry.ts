/**
 * Whether this machine shares anonymous usage data, kept in the data folder's `telemetry.json` by `orion server start`.
 * The app reads the choice, records the person's answer, and asks for shared data to be deleted; the CLI owns the file
 * and the environment overrides.
 */
const API = '/api/telemetry'
/** Long enough for a local server, short enough that a missing one doesn't hold anything up. */
const READ_TIMEOUT_MS = 1500

/** The published list of every event Orion sends once someone opts in. */
export const TELEMETRY_EVENTS_URL = 'https://oriongraph.app/reference/telemetry'

export type TelemetryStatus = {
  choice: 'undecided' | 'on' | 'off'
  installId?: string
  /** The environment variable that turns telemetry off whatever was chosen, such as `DO_NOT_TRACK`. */
  override?: string
  enabled: boolean
}

/** The choice for this machine, or null with no server to ask, as in Storybook and perf runs. */
export async function readTelemetry(): Promise<TelemetryStatus | null> {
  try {
    const response = await fetch(API, { signal: AbortSignal.timeout(READ_TIMEOUT_MS) })

    return response.ok ? ((await response.json()) as TelemetryStatus) : null
  } catch {
    return null
  }
}

/** Records the person's answer and returns the status it leaves. Rejects when the server doesn't save it. */
export async function chooseTelemetry(enabled: boolean): Promise<TelemetryStatus> {
  const response = await fetch(API, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ enabled }),
  })

  if (!response.ok) throw new Error(`telemetry choice failed: ${response.status}`)

  return (await response.json()) as TelemetryStatus
}

/**
 * Deletes every event this machine has shared and returns the status it leaves, with sharing off and no install id.
 * When the machine had shared nothing, `deleted` is false and nothing changes. Rejects with the reason when the server
 * or the telemetry backend couldn't delete it, so the person can be told and try again.
 */
export async function deleteTelemetryData(): Promise<TelemetryStatus & { deleted: boolean }> {
  const response = await fetch(`${API}/delete`, { method: 'POST' })
  const body = (await response.json().catch(() => ({}))) as Partial<TelemetryStatus> & {
    deleted?: boolean
    error?: string
  }

  if (!response.ok) throw new Error(body.error ?? `deleting usage data failed: ${response.status}`)

  return body as TelemetryStatus & { deleted: boolean }
}

/** Whether to ask on launch: nobody has answered, and no override has already answered for them. */
export const shouldAskTelemetry = (status: TelemetryStatus | null) => status?.choice === 'undecided' && !status.override

/**
 * One usage event, named from the list Orion publishes at TELEMETRY_EVENTS_URL. Its properties hold counts, durations,
 * flags, and names Orion defines, such as a tool name. They never hold what someone wrote.
 */
export type TelemetryEvent = {
  name: string
  properties?: Record<string, string | number | boolean>
}

/** An id for this run of the app, from launch to quit. Every event carries it, so a session's events read together. */
export const TELEMETRY_SESSION_ID = crypto.randomUUID()

/**
 * Hands events to `orion server start`, which queues them when this machine shares usage data and sends them on to the
 * telemetry backend later. A failure only logs a warning in the console and never throws, so callers can send without
 * awaiting the result.
 */
export async function sendTelemetryEvents(events: TelemetryEvent[]): Promise<void> {
  if (events.length === 0) return

  const timestamp = new Date().toISOString()
  const body = JSON.stringify({
    events: events.map((event) => ({ ...event, sessionId: TELEMETRY_SESSION_ID, timestamp })),
  })

  try {
    const response = await fetch(`${API}/events`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body,
      keepalive: true,
    })

    if (!response.ok) console.warn('Could not queue usage events', response.status)
  } catch (error) {
    console.warn('Could not queue usage events', error)
  }
}
