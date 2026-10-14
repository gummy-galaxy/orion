import type { AppNode, GithubSnapshot, Link, TaskData } from './model'
import { loadoutOf, type Loadout, type Sticker } from './sticker'
import type { CardSize } from './cardSize'
import { toStored } from './skinSpace'

/**
 * The canvas lives in orion.json, served by the Orion CLI so the CLI and the
 * app share one copy. Without that server (a static build), it falls back to
 * this browser's storage.
 */

export type Saved = { nodes: AppNode[]; links: Link[]; stickers?: Sticker[]; stickerLoadout?: Loadout }
export type Remote = Saved & { revision: number; settings: Record<string, unknown>; github?: GithubSnapshot }
export type SyncStatus = { state: 'idle' | 'running' | 'error' | 'unavailable'; lastRun?: string; message?: string }
export type Loaded = { source: 'file'; doc: Remote } | { source: 'missing'; workspace: string } | { source: 'browser'; saved: Saved | null }
export type SaveResult = { ok: true; revision: number } | { ok: false; conflict: boolean }
export type Workspaces = { active: string; workspaces: { name: string; label: string }[] }

const API = '/api/orion'
const STORAGE_KEY = 'orion:v2'
const CHANGED_EVENT = 'orion:changed'
const SYNC_EVENT = 'orion:sync'
const WORKSPACE_EVENT = 'orion:workspace'
const WORKSPACES_EVENT = 'orion:workspaces'
const MAX_IMAGE_BYTES = 5 * 1024 * 1024

export type ImageAsset = { asset: string; mime: string }

export async function importImage(file: File, workspace: string): Promise<ImageAsset> {
  if (file.size === 0 || file.size > MAX_IMAGE_BYTES) throw new Error('Choose an image smaller than 5 MB.')

  const response = await fetch(`/api/images?workspace=${encodeURIComponent(workspace)}`, { method: 'POST', body: file })

  if (!response.ok) {
    const body = (await response.json().catch(() => ({}))) as { error?: string }

    throw new Error(body.error ?? 'Could not add the image.')
  }

  return (await response.json()) as ImageAsset
}

/** Saves a canvas's cover or background. The server bumps the revision and announces it, so open windows reload. */
export async function saveCanvasStyle(workspace: string, change: { cover?: string | null; background?: string | null }): Promise<boolean> {
  try {
    const response = await fetch('/api/orion/style', {
      method: 'PUT',
      headers: { 'content-type': 'application/json', 'x-orion-workspace': workspace },
      body: JSON.stringify(change),
    })

    return response.ok
  } catch {
    return false
  }
}

/** Snoozes a CI job for every card in its repository, or ends its snooze. The server bumps the revision, so open windows reload. */
export async function saveCheckSnooze(workspace: string, change: { repo: string; name: string; snoozed: boolean; until?: string }): Promise<boolean> {
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
  const response = await fetch(`/api/images/${encodeURIComponent(asset)}?workspace=${encodeURIComponent(workspace)}`)

  if (!response.ok || !response.headers.get('content-type')?.startsWith('image/')) throw new Error('Image unavailable')

  return URL.createObjectURL(await response.blob())
}

/** The card a pasted link names: one already on the canvas, or a new one that isn't saved until the app places it. */
export type LinkLookup = { status: 'existing'; id: string; label: string } | { status: 'found'; id: string; data: TaskData }

export async function lookupLink(url: string, workspace: string): Promise<LinkLookup> {
  const unserved = new Error('Creating from a link needs orion serve.')
  const response = await fetch(`/api/links?workspace=${encodeURIComponent(workspace)}`, {
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

type EventName = typeof CHANGED_EVENT | typeof SYNC_EVENT | typeof WORKSPACE_EVENT | typeof WORKSPACES_EVENT
const listeners = new Map<EventName, Set<(data: never) => void>>()
let socket: WebSocket | undefined
let retryTimer: ReturnType<typeof setTimeout> | undefined
let retryDelay = 250

function connectEvents() {
  if (typeof WebSocket === 'undefined' || socket || listeners.size === 0) return

  const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:'
  const current = new WebSocket(`${protocol}//${location.host}/api/events`)

  socket = current

  current.onopen = () => {
    retryDelay = 250
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

export async function getWorkspaces(): Promise<Workspaces> {
  try {
    const response = await fetch('/api/workspaces')

    if (response.ok) return (await response.json()) as Workspaces
  } catch {
    // A static build has only browser storage for the default workspace.
  }

  return { active: 'default', workspaces: [{ name: 'default', label: 'Default' }] }
}

async function workspaceRequest(url: string, value: object): Promise<Workspaces> {
  const response = await fetch(url, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(value) })
  const result = await response.json()

  if (!response.ok) throw new Error(result.error || `Workspace request failed (${response.status})`)

  return result as Workspaces
}

export const setActiveWorkspace = (name: string) => workspaceRequest('/api/workspaces/active', { name })
export const createWorkspace = (name: string, label: string) => workspaceRequest('/api/workspaces', { name, label })

export function onWorkspaceChange(callback: (active: string) => void) {
  return subscribe<{ active: string }>(WORKSPACE_EVENT, (data) => callback(data.active))
}

/** Updates the list when another client creates or edits a workspace. */
export function onWorkspaceListChange(callback: (list: Workspaces) => void) {
  return subscribe<Workspaces>(WORKSPACES_EVENT, callback)
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

/** Only what's worth keeping; selection, measurements and handles are view state. */
export function slim(nodes: AppNode[]) {
  return nodes.map((node) => ({
    id: node.id,
    type: node.type,
    position: node.position,
    parentId: node.parentId,
    data: node.data,
    width: node.width,
    height: node.height,
  }))
}

/** A stable fingerprint, so view-only changes don't cause writes. */
export const fingerprint = ({ nodes, links, stickers, stickerLoadout }: Saved) =>
  JSON.stringify({ nodes: slim(nodes), links, stickers, stickerLoadout })

/** The stored shape of a document, for comparing and merging. */
export const compactDoc = (doc: Saved): Saved =>
  JSON.parse(fingerprint({ ...doc, stickers: doc.stickers ?? [], stickerLoadout: loadoutOf(doc.stickerLoadout) })) as Saved

function isSaved(value: unknown): value is Saved {
  const saved = value as Saved | null

  return !!saved && Array.isArray(saved.nodes) && Array.isArray(saved.links)
}

export function readBrowser(): Saved | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    const saved = raw ? JSON.parse(raw) : null

    return isSaved(saved) ? saved : null
  } catch {
    return null
  }
}

function writeBrowser({ nodes, links, stickers, stickerLoadout }: Saved) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ nodes: slim(nodes), links, stickers, stickerLoadout }))
  } catch {
    // Saving is a convenience; the canvas keeps working without it.
  }
}

export async function load(workspace = 'default'): Promise<Loaded> {
  try {
    const response = await fetch(API, { headers: { 'x-orion-workspace': workspace } })

    if (response.status === 404) {
      const body = (await response.json()) as { workspace?: string }

      return { source: 'missing', workspace: body.workspace ?? 'default' }
    }

    if (response.ok && response.headers.get('content-type')?.includes('json')) {
      const doc = await response.json()

      if (isSaved(doc) && typeof (doc as Remote).revision === 'number') return { source: 'file', doc: doc as Remote }
    }
  } catch {
    // No dev server.
  }

  return workspace === 'default' ? { source: 'browser', saved: readBrowser() } : { source: 'missing', workspace }
}

export async function fetchRemote(workspace = 'default'): Promise<Remote | null> {
  const loaded = await load(workspace)

  return loaded.source === 'file' ? loaded.doc : null
}

/** `baseRevision` is null when creating the file. */
export async function save(
  source: 'file' | 'browser',
  baseRevision: number | null,
  saved: Saved,
  workspace = 'default',
  cardSize: CardSize,
): Promise<SaveResult> {
  saved = { ...saved, nodes: toStored(saved.nodes, cardSize) }

  if (source === 'browser') {
    writeBrowser(saved)

    return { ok: true, revision: 0 }
  }

  try {
    const response = await fetch(API, {
      method: 'PUT',
      headers: { 'content-type': 'application/json', 'x-orion-workspace': workspace },
      body: JSON.stringify({
        baseRevision,
        nodes: slim(saved.nodes),
        links: saved.links,
        stickers: saved.stickers,
        stickerLoadout: saved.stickerLoadout,
      }),
    })

    if (response.ok) return { ok: true, revision: (await response.json()).revision }

    return { ok: false, conflict: response.status === 409 }
  } catch {
    return { ok: false, conflict: false }
  }
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
    body: JSON.stringify({ tab: TAB_ID, workspace, ...report }),
  }).catch(() => {
    // No server is available to record this page.
  })
}

/** Withdraws this page's focus as it goes away. */
export function clearFocus(workspace: string) {
  navigator.sendBeacon?.(FOCUS_API, new Blob([JSON.stringify({ tab: TAB_ID, workspace, closed: true })], { type: 'application/json' }))
}

/** Calls back when another writer (the CLI, an agent, another window) changes the file. */
export function onRemoteChange(callback: (revision: number) => void) {
  return subscribe<{ revision: number }>(CHANGED_EVENT, (data) => callback(data.revision))
}

import.meta.hot?.dispose(() => {
  clearTimeout(retryTimer)
  socket?.close()
  socket = undefined
  listeners.clear()
})
