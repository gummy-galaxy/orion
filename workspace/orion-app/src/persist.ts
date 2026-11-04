import { registerCardTypes } from './cardTypes/registerCardTypes'
import type { Derived } from './derive'
import { IMAGE_MAX_BYTES } from './geometry'
import {
  isComponent,
  isNote,
  normalize,
  type AppNode,
  type GithubSnapshot,
  type Link,
  type SourceRef,
  type TaskData,
  type ViewStatus,
} from './model'
import { loadoutOf, type Loadout, type Sticker } from './sticker'
import type { Operation } from './operations'
import { stableJson } from './stableJson'
import type { CardSize } from './cardSize'
import { toDisplayed, toStored } from './skinSpace'

/**
 * The canvas lives in orion.json, served by `orion serve`, which is the only store. The app reads it, and every
 * committed edit goes to the server as operations. Without a server the canvas shows empty and nothing is saved.
 */

export type Saved = { nodes: AppNode[]; links: Link[]; stickers?: Sticker[]; stickerLoadout?: Loadout }
/** `derived` is what `orion serve` computed for this revision; a server without it leaves the field out. */
export type Remote = Saved & {
  revision: number
  settings: Record<string, unknown>
  github?: GithubSnapshot
  derived?: Derived
}
export type SyncStatus = { state: 'idle' | 'running' | 'error' | 'unavailable'; lastRun?: string; message?: string }
export type Loaded = { source: 'file'; doc: Remote } | { source: 'missing'; workspace: string }
/** `results` holds what each operation answered, such as a chain close's cards, or null, in the order sent. */
export type CommitResult =
  { ok: true; revision: number; results: unknown[] } | { ok: false; conflict: boolean; message?: string }
export type Workspaces = { active: string; canvases: { name: string; label: string }[] }
/** What `orion reveal` asked the open app to select and frame, on the canvas named. */
export type Reveal = { canvas: string; ids: string[]; selectOnly: boolean }
/** A query for `orion serve`, with `orion node query`'s options. A blank `where` matches every node. */
export type QueryRequest = { where?: string; sort?: string; offset?: number; limit?: number; all?: boolean }
/**
 * One node in a query's answer, the way `orion node query --json` prints it. Only the fields the app reads are listed.
 */
export type QueryRow = {
  id: string
  kind: string
  label?: string
  status?: ViewStatus
  group?: string
  groupLabel?: string
  refs?: SourceRef[]
}
/** One page of a query's matches, read at `revision`, with `total` counting every match before paging. */
export type QueryAnswer =
  { canvas: string; revision: number; total: number; offset: number; rows: QueryRow[] } | { error: string }

const API = '/api/orion'
const OPERATIONS_API = '/api/operations'
const CHANGED_EVENT = 'orion:changed'
const SYNC_EVENT = 'orion:sync'
const WORKSPACE_EVENT = 'orion:canvas'
const WORKSPACES_EVENT = 'orion:canvases'
const REVEAL_EVENT = 'orion:reveal'
const LOG_EVENT = 'orion:log'
const QUERY_EVENT = 'orion:query'

export type ImageAsset = { asset: string; mime: string }

export async function importImage(file: File, workspace: string): Promise<ImageAsset> {
  if (file.size === 0 || file.size > IMAGE_MAX_BYTES) throw new Error('Choose an image smaller than 5 MB.')

  const response = await fetch(`/api/images?canvas=${encodeURIComponent(workspace)}`, { method: 'POST', body: file })

  if (!response.ok) {
    const body = (await response.json().catch(() => ({}))) as { error?: string }

    throw new Error(body.error ?? 'Could not add the image.')
  }

  return (await response.json()) as ImageAsset
}

/** Saves a canvas's cover or background. The server bumps the revision and announces it, so open windows reload. */
export async function saveCanvasStyle(
  workspace: string,
  change: { cover?: string | null; background?: string | null; header?: string | null },
): Promise<boolean> {
  try {
    const response = await fetch('/api/orion/style', {
      method: 'PUT',
      headers: { 'content-type': 'application/json', 'x-orion-canvas': workspace },
      body: JSON.stringify(change),
    })

    return response.ok
  } catch {
    return false
  }
}

/**
 * Snoozes a CI job for every card in its repository, or ends its snooze. The server bumps the revision, so open windows
 * reload.
 */
export async function saveCheckSnooze(
  workspace: string,
  change: { repo: string; name: string; snoozed: boolean; until?: string },
): Promise<boolean> {
  try {
    const response = await fetch('/api/orion/check-snoozes', {
      method: 'PUT',
      headers: { 'content-type': 'application/json', 'x-orion-workspace': workspace },
      body: JSON.stringify(change),
    })

    return response.ok
  } catch {
    return false
  }
}

export async function imageSource(workspace: string, asset: string): Promise<string> {
  const response = await fetch(`/api/images/${encodeURIComponent(asset)}?canvas=${encodeURIComponent(workspace)}`)

  if (!response.ok || !response.headers.get('content-type')?.startsWith('image/')) throw new Error('Image unavailable')

  return URL.createObjectURL(await response.blob())
}

/** Copies an image from one workspace's assets into another's, and returns its id there. */
export async function copyImage(asset: string, from: string, to: string): Promise<string> {
  const response = await fetch(`/api/images/${encodeURIComponent(asset)}?workspace=${encodeURIComponent(from)}`)

  if (!response.ok || !response.headers.get('content-type')?.startsWith('image/')) throw new Error('Image unavailable')

  const blob = await response.blob()

  return (await importImage(new File([blob], asset, { type: blob.type }), to)).asset
}

/** The card a pasted link names: one already on the canvas, or a new one that isn't saved until the app places it. */
export type LinkLookup =
  { status: 'existing'; id: string; label: string } | { status: 'found'; id: string; data: TaskData }

export async function lookupLink(url: string, workspace: string): Promise<LinkLookup> {
  const unserved = new Error('Creating from a link needs orion server start.')
  const response = await fetch(`/api/links?canvas=${encodeURIComponent(workspace)}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ url }),
  }).catch(() => {
    throw unserved
  })

  // A static build answers with its page, or nothing, rather than JSON.
  if (!response.headers.get('content-type')?.includes('json')) throw unserved

  const body = (await response.json()) as LinkLookup & { error?: string }

  if (!response.ok) throw new Error(body.error ?? 'Could not look up that link.')

  return body
}

type EventName =
  | typeof CHANGED_EVENT
  | typeof SYNC_EVENT
  | typeof WORKSPACE_EVENT
  | typeof WORKSPACES_EVENT
  | typeof REVEAL_EVENT
  | typeof LOG_EVENT
  | typeof QUERY_EVENT
const listeners = new Map<EventName, Set<(data: never) => void>>()
/** The queries the app keeps open, by id, sent again whenever the socket reconnects. */
const openQueries = new Map<string, QueryRequest>()
let socket: WebSocket | undefined
let lastQueryId = 0
let retryTimer: ReturnType<typeof setTimeout> | undefined
let retryDelay = 250

function connectEvents() {
  if (typeof WebSocket === 'undefined' || socket || listeners.size === 0) return

  const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:'
  const current = new WebSocket(`${protocol}//${location.host}/api/events`)

  socket = current

  current.onopen = () => {
    retryDelay = 250
    openQueries.forEach((request, id) => sendQuery({ type: 'query', id, ...request }))
  }

  current.onmessage = (message) => {
    try {
      const event = JSON.parse(message.data) as { event: EventName; data: never }

      listeners.get(event.event)?.forEach((callback) => callback(event.data))
    } catch {
      // Ignore malformed messages from a restarting server.
    }
  }

  current.onclose = () => {
    if (socket !== current) return

    socket = undefined

    if (listeners.size > 0) {
      retryTimer = setTimeout(connectEvents, retryDelay)
      retryDelay = Math.min(retryDelay * 2, 10000)
    }
  }

  current.onerror = () => current.close()
}

function subscribe<T>(event: EventName, callback: (data: T) => void) {
  const callbacks = listeners.get(event) ?? new Set<(data: never) => void>()

  callbacks.add(callback as (data: never) => void)
  listeners.set(event, callbacks)
  connectEvents()

  return () => {
    callbacks.delete(callback as (data: never) => void)

    if (callbacks.size === 0) listeners.delete(event)

    if (listeners.size === 0) {
      clearTimeout(retryTimer)
      socket?.close()
      socket = undefined
    }
  }
}

function sendQuery(message: { type: 'query' | 'unquery'; id: string }) {
  if (socket && socket.readyState === socket.OPEN) socket.send(JSON.stringify(message))
}

/**
 * Keeps a query open on the active canvas. `orion serve` answers right away and again whenever a change alters the
 * answer, so a change that leaves the rows alone, such as moving a card, sends nothing.
 */
export function watchQuery(request: QueryRequest, callback: (answer: QueryAnswer) => void) {
  const id = `query-${++lastQueryId}`
  const unsubscribe = subscribe<QueryAnswer & { id: string }>(QUERY_EVENT, ({ id: answered, ...answer }) => {
    if (answered === id) callback(answer)
  })

  openQueries.set(id, request)
  sendQuery({ type: 'query', id, ...request })

  return () => {
    openQueries.delete(id)
    sendQuery({ type: 'unquery', id })
    unsubscribe()
  }
}

export async function getWorkspaces(): Promise<Workspaces> {
  try {
    const response = await fetch('/api/canvases')

    if (response.ok) return (await response.json()) as Workspaces
  } catch {
    // A static build has only browser storage for the default workspace.
  }

  return { active: 'default', canvases: [{ name: 'default', label: 'Default' }] }
}

async function workspaceRequest(url: string, value: object): Promise<Workspaces> {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(value),
  })
  const result = await response.json()

  if (!response.ok) throw new Error(result.error || `Canvas request failed (${response.status})`)

  return result as Workspaces
}

export const setActiveWorkspace = (name: string) => workspaceRequest('/api/canvases/active', { name })
export const createWorkspace = (name: string, label: string) => workspaceRequest('/api/canvases', { name, label })

export function onWorkspaceChange(callback: (active: string) => void) {
  return subscribe<{ active: string }>(WORKSPACE_EVENT, (data) => callback(data.active))
}

/** Updates the list when another client creates or edits a workspace. */
export function onWorkspaceListChange(callback: (list: Workspaces) => void) {
  return subscribe<Workspaces>(WORKSPACES_EVENT, callback)
}

/** Calls back when `orion reveal` (or an agent) asks this page to select cards and zoom to them. */
export function onReveal(callback: (reveal: Reveal) => void) {
  return subscribe<Reveal>(REVEAL_EVENT, callback)
}

/** Runs when another writer appends to a canvas's log, with that canvas's name. Appends don't change the document. */
export function onLogChange(callback: (workspace: string) => void) {
  return subscribe<{ canvas: string }>(LOG_EVENT, (data) => callback(data.canvas))
}

export async function getSyncStatus(): Promise<SyncStatus | null> {
  try {
    const response = await fetch('/api/sync')

    return response.ok ? ((await response.json()) as SyncStatus) : null
  } catch {
    return null
  }
}

export async function requestSync(force = false): Promise<SyncStatus | null> {
  try {
    const response = await fetch(force ? '/api/sync?force=1' : '/api/sync', { method: 'POST' })

    return response.ok ? ((await response.json()) as SyncStatus) : null
  } catch {
    return null
  }
}

export function onSyncStatus(callback: (status: SyncStatus) => void) {
  return subscribe(SYNC_EVENT, callback)
}

/**
 * Sends a list of edits the server applies as one change. `baseRevision` is the revision the edits were made against,
 * or null when the file doesn't exist yet. A conflict means the file changed since, and the list was not applied.
 */
export async function commitOperations(
  workspace: string,
  baseRevision: number | null,
  operations: Operation[],
): Promise<CommitResult> {
  try {
    const response = await fetch(OPERATIONS_API, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-orion-canvas': workspace },
      body: JSON.stringify({ baseRevision, operations }),
    })

    if (response.ok) {
      const body = (await response.json()) as { revision: number; results?: unknown[] }

      return { ok: true, revision: body.revision, results: body.results ?? [] }
    }

    const failure = (await response.json().catch(() => ({}))) as { error?: unknown }

    return {
      ok: false,
      conflict: response.status === 409,
      message: typeof failure.error === 'string' ? failure.error : undefined,
    }
  } catch {
    return { ok: false, conflict: false }
  }
}

/**
 * The stored fields of each node; selection and handles are view state. Groups and images keep their size. Notes and
 * components keep the size the app measured for their text, so the CLI places work around them without guessing; work
 * cards are always one size, so they keep none.
 */
export function slim(nodes: AppNode[]) {
  return nodes.map((node) => {
    const sized = node.type !== 'task' || isNote(node) || isComponent(node)

    return {
      id: node.id,
      type: node.type,
      position: node.position,
      parentId: node.parentId,
      data: node.data,
      width: sized ? node.width : undefined,
      height: sized ? node.height : undefined,
    }
  })
}

/** A stable fingerprint, so view-only changes don't cause writes. */
export const fingerprint = ({ nodes, links, stickers, stickerLoadout }: Saved) =>
  stableJson({ nodes: slim(nodes), links, stickers, stickerLoadout })

/** The stored shape of a document, for comparing and merging. */
export const compactDoc = (doc: Saved): Saved =>
  JSON.parse(
    fingerprint({ ...doc, stickers: doc.stickers ?? [], stickerLoadout: loadoutOf(doc.stickerLoadout) }),
  ) as Saved

/** A document as the canvas shows it at this card size. */
export function displayedDoc(doc: Saved, cardSize: CardSize): Saved & { stickers: Sticker[]; stickerLoadout: Loadout } {
  return {
    nodes: toDisplayed(normalize(doc.nodes), cardSize),
    links: doc.links,
    stickers: doc.stickers ?? [],
    stickerLoadout: loadoutOf(doc.stickerLoadout),
  }
}

/** The fingerprint of what saving this canvas would write. Stickers on cards or groups that are gone go with them. */
export function storedPrint({ nodes, links, stickers = [], stickerLoadout }: Saved, cardSize: CardSize): string {
  const ids = new Set(nodes.map((node) => node.id))

  return fingerprint({
    nodes: toStored(nodes, cardSize),
    links,
    stickers: stickers.filter((sticker) => !sticker.on || ids.has(sticker.on)),
    stickerLoadout: loadoutOf(stickerLoadout),
  })
}

/**
 * The fingerprint of a server document once adopted, so the canvas saves only what differs from it. It goes through
 * the same display and storage mapping as a save, since the CLI writes keys in its own order and a card size other
 * than the classic one rounds positions on the way back.
 */
export function adoptedPrint(serverDoc: Saved, cardSize: CardSize): string {
  return storedPrint(displayedDoc(serverDoc, cardSize), cardSize)
}

function isSaved(value: unknown): value is Saved {
  const saved = value as Saved | null

  return !!saved && Array.isArray(saved.nodes) && Array.isArray(saved.links)
}

export async function load(workspace = 'default'): Promise<Loaded> {
  try {
    const response = await fetch(API, { headers: { 'x-orion-canvas': workspace } })

    if (response.status === 404) {
      const body = (await response.json()) as { canvas?: string }

      return { source: 'missing', workspace: body.canvas ?? 'default' }
    }

    if (response.ok && response.headers.get('content-type')?.includes('json')) {
      const doc = await response.json()

      if (isSaved(doc) && typeof (doc as Remote).revision === 'number') {
        // The server declares every card type, including ones its sources add, and cards draw from those.
        registerCardTypes((doc as { types?: unknown }).types)

        return { source: 'file', doc: doc as Remote }
      }
    }
  } catch {
    // No dev server.
  }

  return { source: 'missing', workspace }
}

export async function fetchRemote(workspace = 'default'): Promise<Remote | null> {
  const loaded = await load(workspace)

  return loaded.source === 'file' ? loaded.doc : null
}

export type FocusReport = { open: string | null; selected: string[] }

const FOCUS_API = '/api/focus'
// Each page reports under its own id, so closing one page leaves another's focus alone.
const TAB_ID = crypto.randomUUID()

/** Tells agents, through `orion focus`, what this page has open and selected. */
export function reportFocus(report: FocusReport, workspace: string) {
  void fetch(FOCUS_API, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ tab: TAB_ID, canvas: workspace, ...report }),
  }).catch(() => {
    // No server is available to record this page.
  })
}

/** Withdraws this page's focus as it goes away. */
export function clearFocus(workspace: string) {
  navigator.sendBeacon?.(
    FOCUS_API,
    new Blob([JSON.stringify({ tab: TAB_ID, canvas: workspace, closed: true })], { type: 'application/json' }),
  )
}

/**
 * Calls back when another writer (the CLI, an agent, another window) changes the file, with the derived values for that
 * revision. `reindexed` means the canvas's files changed outside Orion, such as by a `git pull`, without a new
 * revision.
 */
export function onRemoteChange(callback: (revision: number, derived?: Derived, reindexed?: boolean) => void) {
  return subscribe<{ revision: number; derived?: Derived; reindexed?: boolean }>(CHANGED_EVENT, (data) =>
    callback(data.revision, data.derived, data.reindexed === true),
  )
}

import.meta.hot?.dispose(() => {
  clearTimeout(retryTimer)
  socket?.close()
  socket = undefined
  listeners.clear()
})
