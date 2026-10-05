import { migrateNodes, type AppNode, type GithubSnapshot, type Link } from './model'

/**
 * The canvas lives in orion.json, served by the dev server so the CLI and the
 * app share one copy. Without that server (a static build), it falls back to
 * this browser's storage.
 */

export type Saved = { nodes: AppNode[]; links: Link[] }
export type Remote = Saved & { revision: number; settings: { githubOwner: string }; github?: GithubSnapshot }
export type SyncStatus = { state: 'idle' | 'running' | 'error' | 'unavailable'; lastRun?: string; message?: string }
export type Loaded = { source: 'file'; doc: Remote } | { source: 'missing'; workspace: string } | { source: 'browser'; saved: Saved | null }
export type SaveResult = { ok: true; revision: number } | { ok: false; conflict: boolean }
export type Workspaces = { active: string; workspaces: { name: string; label: string }[] }

const API = '/api/orion'
const STORAGE_KEY = 'orion:v2'
const CHANGED_EVENT = 'orion:changed'
const SYNC_EVENT = 'orion:sync'
const WORKSPACE_EVENT = 'orion:workspace'

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
  const hot = import.meta.hot
  if (!hot) return () => {}
  const listener = (data: { active: string }) => callback(data.active)
  hot.on(WORKSPACE_EVENT, listener)
  return () => hot.off(WORKSPACE_EVENT, listener)
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
    return isSaved(s) ? { ...s, nodes: migrateNodes(s.nodes) } : null
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

export async function load(workspace = 'default'): Promise<Loaded> {
  try {
    const res = await fetch(API)
    if (res.status === 404) {
      const body = (await res.json()) as { workspace?: string }
      return { source: 'missing', workspace: body.workspace ?? 'default' }
    }
    if (res.ok && res.headers.get('content-type')?.includes('json')) {
      const doc = await res.json()
      if (isSaved(doc) && typeof (doc as Remote).revision === 'number')
        return { source: 'file', doc: { ...(doc as Remote), nodes: migrateNodes(doc.nodes) } }
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
export async function save(source: 'file' | 'browser', baseRevision: number | null, saved: Saved, workspace = 'default'): Promise<SaveResult> {
  if (source === 'browser') {
    writeBrowser(saved)
    return { ok: true, revision: 0 }
  }
  try {
    const res = await fetch(API, {
      method: 'PUT',
      headers: { 'content-type': 'application/json', 'x-orion-workspace': workspace },
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
