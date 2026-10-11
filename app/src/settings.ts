/**
 * Preferences saved in the data folder through `orion serve`. The desktop app's page gets a new
 * origin each launch, which starts browser storage empty, so the server's copy is the one that
 * lasts. Browser storage still caches each value for code that reads it synchronously.
 */
const API = '/api/settings'
const PREFIX = 'orion:'
/** Storage keys, without the prefix, that are kept in the data folder. */
const SAVED = ['theme', 'color-mode', 'sidebar', 'debug', 'motion', 'scrolling', 'keybindings'] as const
/** Long enough for a local server, short enough not to hold up the first render when there's none. */
const RESTORE_TIMEOUT_MS = 1500

export type SavedSetting = (typeof SAVED)[number]

// The file holds JSON values where the stored text is JSON, so motion reads as an object there.
const toFile = (stored: string): unknown => {
  try {
    return JSON.parse(stored)
  } catch {
    return stored
  }
}

const fromFile = (value: unknown) => (typeof value === 'string' ? value : JSON.stringify(value))

function readStored(key: SavedSetting): string | null {
  try {
    return localStorage.getItem(PREFIX + key)
  } catch {
    return null
  }
}

function writeStored(key: SavedSetting, value: string | null) {
  try {
    if (value === null) localStorage.removeItem(PREFIX + key)
    else localStorage.setItem(PREFIX + key, value)
  } catch {
    // Only a cache of the saved copy.
  }
}

let posting: Promise<unknown> = Promise.resolve()

// One at a time, since the server reads, merges, and writes the whole file for each.
function post(changes: Record<string, unknown>) {
  posting = posting
    .then(() => fetch(API, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(changes) }))
    .catch(() => {
      // No server, as in Storybook; browser storage keeps the value for this origin.
    })
}

/**
 * Copies the saved preferences into browser storage before the app reads them. Preferences
 * only this browser has, from before they were saved in the data folder, are sent up once.
 */
export async function restoreSettings() {
  let saved: Record<string, unknown>

  try {
    const response = await fetch(API, { signal: AbortSignal.timeout(RESTORE_TIMEOUT_MS) })

    if (!response.ok) return

    saved = (await response.json()) as Record<string, unknown>
  } catch {
    return
  }

  const missing: Record<string, unknown> = {}

  for (const key of SAVED) {
    const stored = readStored(key)

    if (key in saved) writeStored(key, fromFile(saved[key]))
    else if (stored !== null) missing[key] = toFile(stored)
  }

  if (Object.keys(missing).length) post(missing)
}

/** Saves preferences here and in the data folder. Null forgets one. */
export function saveSettings(changes: Partial<Record<SavedSetting, string | null>>) {
  const sent: Record<string, unknown> = {}

  for (const [key, value] of Object.entries(changes) as [SavedSetting, string | null][]) {
    writeStored(key, value)
    sent[key] = value === null ? null : toFile(value)
  }

  post(sent)
}
