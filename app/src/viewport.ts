import type { Viewport } from '@xyflow/react'

/** Where you were looking is this device's view state, so it stays out of orion.json. */
type ViewStore = Pick<Storage, 'getItem' | 'setItem'>

const KEY = 'orion:viewport:'

const browserStore = (): ViewStore | null => {
  try {
    return localStorage
  } catch {
    return null
  }
}

function isViewport(value: unknown): value is Viewport {
  const viewport = value as Viewport | null

  return !!viewport && Number.isFinite(viewport.x) && Number.isFinite(viewport.y) && Number.isFinite(viewport.zoom) && viewport.zoom > 0
}

export function readViewport(workspace: string, store = browserStore()): Viewport | null {
  try {
    const raw = store?.getItem(KEY + workspace)
    const value: unknown = raw ? JSON.parse(raw) : null

    return isViewport(value) ? { x: value.x, y: value.y, zoom: value.zoom } : null
  } catch {
    return null
  }
}

export function writeViewport(workspace: string, { x, y, zoom }: Viewport, store = browserStore()) {
  if (!isViewport({ x, y, zoom })) return

  try {
    store?.setItem(KEY + workspace, JSON.stringify({ x, y, zoom }))
  } catch {
    // Only a remembered view.
  }
}
