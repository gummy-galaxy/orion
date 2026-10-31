/**
 * Whether this machine shares anonymous usage data, kept in the data folder's `telemetry.json` by `orion server start`.
 * The app only reads the choice and records the person's answer; the CLI owns the file and the environment overrides.
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

/** Whether to ask on launch: nobody has answered, and no override has already answered for them. */
export const shouldAskTelemetry = (status: TelemetryStatus | null) => status?.choice === 'undecided' && !status.override
