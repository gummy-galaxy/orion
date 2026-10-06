import { migrateNodes, type AppNode, type GithubSnapshot, type Link } from './model'
import type { Loadout, Sticker } from './sticker'
import { invoke, isTauri } from '@tauri-apps/api/core'

/**
 * The canvas lives in orion.json. The browser uses the dev server, and Tauri
 * uses native commands that take the same lock as the CLI. A static browser
 * build falls back to browser storage.
 */

export type Saved = { nodes: AppNode[]; links: Link[]; stickers?: Sticker[]; stickerLoadout?: Loadout }
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
const WORKSPACES_EVENT = 'orion:workspaces'
const NATIVE_POLL_MS = 1000
const MAX_IMAGE_BYTES = 5 * 1024 * 1024

export type ImageAsset = { asset: string; mime: string }

export async function importImage(file: File, workspace: string): Promise<ImageAsset> {
  if (file.size === 0 || file.size > MAX_IMAGE_BYTES) throw new Error('Choose an image smaller than 5 MB.')
  if (isTauri()) {
    const bytes = Array.from(new Uint8Array(await file.arrayBuffer()))
    return invoke<ImageAsset>('orion_import_image', { workspace, bytes })
  }
  const response = await fetch(`/api/images?workspace=${encodeURIComponent(workspace)}`, { method: 'POST', body: file })
  if (!response.ok) {
    const body = (await response.json().catch(() => ({}))) as { error?: string }
    throw new Error(body.error ?? 'Could not add the image. Open Orion in the desktop app or dev server.')
  }
  return (await response.json()) as ImageAsset
}

export async function imageSource(workspace: string, asset: string): Promise<string> {
  const mime = asset.endsWith('.png') ? 'image/png' : asset.endsWith('.jpg') ? 'image/jpeg' : asset.endsWith('.gif') ? 'image/gif' : 'image/webp'
  if (isTauri()) {
    const bytes = await invoke<number[]>('orion_image_bytes', { workspace, asset })
    return URL.createObjectURL(new Blob([new Uint8Array(bytes)], { type: mime }))
  }
  const response = await fetch(`/api/images/${encodeURIComponent(asset)}?workspace=${encodeURIComponent(workspace)}`)
  if (!response.ok || !response.headers.get('content-type')?.startsWith('image/')) throw new Error('Image unavailable')
  return URL.createObjectURL(await response.blob())
}

function pollNative<T>(read: () => Promise<T>, changed: (value: T) => void) {
  let previous: string | undefined
  let reading = false
  let stopped = false
  const check = async () => {
    if (reading || stopped) return
    reading = true
    try {
      const value = await read()
      const key = JSON.stringify(value)
      if (previous !== undefined && previous !== key) changed(value)
      previous = key
    } catch (error) {
      console.warn('[orion] native canvas poll failed', error)
    } finally {
      reading = false
    }
  }
  void check()
  const timer = setInterval(() => void check(), NATIVE_POLL_MS)
  return () => {
    stopped = true
    clearInterval(timer)
  }
}

export async function getWorkspaces(): Promise<Workspaces> {
  if (isTauri()) return invoke<Workspaces>('orion_workspaces')
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

export const setActiveWorkspace = (name: string) =>
  isTauri() ? invoke<Workspaces>('orion_set_active_workspace', { name }) : workspaceRequest('/api/workspaces/active', { name })
export const createWorkspace = (name: string, label: string) =>
  isTauri() ? invoke<Workspaces>('orion_create_workspace', { name, label }) : workspaceRequest('/api/workspaces', { name, label })

export function onWorkspaceChange(callback: (active: string) => void) {
  if (isTauri()) return pollNative(() => getWorkspaces().then((list) => list.active), callback)
  const hot = import.meta.hot
  if (!hot) return () => {}
  const listener = (data: { active: string }) => callback(data.active)
  hot.on(WORKSPACE_EVENT, listener)
  return () => hot.off(WORKSPACE_EVENT, listener)
}

/** Calls back when the workspace list changes on disk, such as a workspace the CLI created. */
export function onWorkspaceListChange(callback: (list: Workspaces) => void) {
  if (isTauri()) return pollNative(getWorkspaces, callback)
  const hot = import.meta.hot
  if (!hot) return () => {}
  hot.on(WORKSPACES_EVENT, callback)
  return () => hot.off(WORKSPACES_EVENT, callback)
}

export async function getSyncStatus(): Promise<SyncStatus | null> {
  if (isTauri()) return { state: 'unavailable', message: 'Automatic sync is not available in the desktop app' }
  try {
    const response = await fetch('/api/sync')
    return response.ok ? ((await response.json()) as SyncStatus) : null
  } catch {
    return null
  }
}

export async function requestSync(force = false): Promise<SyncStatus | null> {
  if (isTauri()) return getSyncStatus()
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
export const fingerprint = ({ nodes, links, stickers, stickerLoadout }: Saved) =>
  JSON.stringify({ nodes: slim(nodes), links, stickers, stickerLoadout })

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

function writeBrowser({ nodes, links, stickers, stickerLoadout }: Saved) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ nodes: slim(nodes), links, stickers, stickerLoadout }))
  } catch {
    // Saving is a convenience; the canvas keeps working without it.
  }
}

export async function load(workspace = 'default'): Promise<Loaded> {
  if (isTauri()) {
    const doc = await invoke<Remote | null>('orion_load', { workspace })
    if (!doc) return { source: 'missing', workspace }
    if (!isSaved(doc) || typeof doc.revision !== 'number') throw new Error('Invalid Orion canvas data')
    return { source: 'file', doc: { ...doc, nodes: migrateNodes(doc.nodes) } }
  }
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
  if (isTauri()) {
    try {
      return await invoke<SaveResult>('orion_save', {
        workspace,
        baseRevision,
        saved: { nodes: slim(saved.nodes), links: saved.links, stickers: saved.stickers, stickerLoadout: saved.stickerLoadout },
      })
    } catch (error) {
      console.error('[orion] native canvas save failed', error)
      return { ok: false, conflict: false }
    }
  }
  try {
    const res = await fetch(API, {
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
    if (res.ok) return { ok: true, revision: (await res.json()).revision }
    return { ok: false, conflict: res.status === 409 }
  } catch {
    return { ok: false, conflict: false }
  }
}

/** Calls back when another writer (the CLI, an agent, another window) changes the file. */
export function onRemoteChange(callback: (revision: number) => void) {
  if (isTauri())
    return pollNative(
      () => invoke<number | null>('orion_revision'),
      (revision) => {
        if (revision !== null) callback(revision)
      },
    )
  const hot = import.meta.hot
  if (!hot) return () => {}
  const listener = (data: { revision: number }) => callback(data.revision)
  hot.on(CHANGED_EVENT, listener)
  return () => hot.off(CHANGED_EVENT, listener)
}
