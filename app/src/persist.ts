import type { AppNode, GithubSnapshot, Link } from './model'

/**
 * The canvas lives in orion.json, served by the dev server so the CLI and the
 * app share one copy. Without that server (a static build), it falls back to
 * this browser's storage.
 */

export type Saved = { nodes: AppNode[]; links: Link[] }
export type Remote = Saved & { revision: number; settings: { githubOwner: string }; github?: GithubSnapshot }
export type SyncStatus = { state: 'idle' | 'running' | 'error' | 'unavailable'; lastRun?: string; message?: string }
export type Loaded = { source: 'file'; doc: Remote } | { source: 'missing' } | { source: 'browser'; saved: Saved | null }
export type SaveResult = { ok: true; revision: number } | { ok: false; conflict: boolean }

const API = '/api/orion'
const STORAGE_KEY = 'orion:v2'
const CHANGED_EVENT = 'orion:changed'
const SYNC_EVENT = 'orion:sync'

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
  const hot = import.meta.hot
  if (!hot) return () => {}
  hot.on(SYNC_EVENT, callback)
  return () => hot.off(SYNC_EVENT, callback)
}

/** Only what's worth keeping; selection, measurements and handles are view state. */
export function slim(nodes: AppNode[]) {
  return nodes.map((n) => ({
    id: n.id,
    type: n.type,
    position: n.position,
    parentId: n.parentId,
    data: n.data,
    width: n.width,
    height: n.height,
  }))
}

/** A stable fingerprint, so view-only changes don't cause writes. */
export const fingerprint = ({ nodes, links }: Saved) => JSON.stringify({ nodes: slim(nodes), links })

function isSaved(value: unknown): value is Saved {
  const s = value as Saved | null
  return !!s && Array.isArray(s.nodes) && Array.isArray(s.links)
}

export function readBrowser(): Saved | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    const s = raw ? JSON.parse(raw) : null
    return isSaved(s) ? s : null
  } catch {
    return null
  }
}

function writeBrowser({ nodes, links }: Saved) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ nodes: slim(nodes), links }))
  } catch {
    // Saving is a convenience; the canvas keeps working without it.
  }
}

export async function load(): Promise<Loaded> {
  try {
    const res = await fetch(API)
    if (res.status === 404) return { source: 'missing' }
    if (res.ok && res.headers.get('content-type')?.includes('json')) {
      const doc = await res.json()
      if (isSaved(doc) && typeof (doc as Remote).revision === 'number') return { source: 'file', doc: doc as Remote }
    }
  } catch {
    // No dev server.
  }
  return { source: 'browser', saved: readBrowser() }
}

export async function fetchRemote(): Promise<Remote | null> {
  const loaded = await load()
  return loaded.source === 'file' ? loaded.doc : null
}

/** `baseRevision` is null when creating the file. */
export async function save(source: 'file' | 'browser', baseRevision: number | null, saved: Saved): Promise<SaveResult> {
  if (source === 'browser') {
    writeBrowser(saved)
    return { ok: true, revision: 0 }
  }
  try {
    const res = await fetch(API, {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ baseRevision, nodes: slim(saved.nodes), links: saved.links }),
    })
    if (res.ok) return { ok: true, revision: (await res.json()).revision }
    return { ok: false, conflict: res.status === 409 }
  } catch {
    return { ok: false, conflict: false }
  }
}

/** Calls back when another writer (the CLI, an agent, another window) changes the file. */
export function onRemoteChange(callback: (revision: number) => void) {
  const hot = import.meta.hot
  if (!hot) return () => {}
  const listener = (data: { revision: number }) => callback(data.revision)
  hot.on(CHANGED_EVENT, listener)
  return () => hot.off(CHANGED_EVENT, listener)
}
