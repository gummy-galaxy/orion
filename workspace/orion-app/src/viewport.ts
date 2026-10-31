import type { Viewport } from '@xyflow/react'
import type { CardSize } from './cardSize'
import { cardPitchOf } from './skinSpace'

export const MIN_ZOOM = 0.06
export const MAX_ZOOM = 2

export function mapViewportForCardSize(
  viewport: Viewport,
  box: { width: number; height: number },
  previousSize: CardSize,
  nextSize: CardSize,
): Viewport {
  const previousPitch = cardPitchOf(previousSize)
  const nextPitch = cardPitchOf(nextSize)
  const scaleX = nextPitch.x / previousPitch.x
  const scaleY = nextPitch.y / previousPitch.y
  const centerX = box.width / 2
  const centerY = box.height / 2
  const worldX = (centerX - viewport.x) / viewport.zoom
  const worldY = (centerY - viewport.y) / viewport.zoom
  const zoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, viewport.zoom / Math.sqrt(scaleX * scaleY)))

  return { x: centerX - worldX * scaleX * zoom, y: centerY - worldY * scaleY * zoom, zoom }
}

/** Every group opens at this zoom, so card text reads the same size wherever you are. */
export const OPEN_ZOOM = 1

type Box = { x: number; y: number; width: number; height: number }

/**
 * Where the camera lands when a group opens: at `OPEN_ZOOM`, centered on each axis the group fits along with its
 * `margin`, and lined up with its left or top edge, past the margin, on an axis it doesn't fit. A big group opens on
 * its first columns and rows, where its dependency flow starts.
 */
export function openGroupViewport(
  group: Box,
  screen: { width: number; height: number },
  margin: { x: number; y: number },
): Viewport {
  const zoom = OPEN_ZOOM

  const place = (start: number, length: number, room: number, edge: number) =>
    (length + edge * 2) * zoom <= room ? room / 2 - (start + length / 2) * zoom : (edge - start) * zoom

  return {
    x: place(group.x, group.width, screen.width, margin.x),
    y: place(group.y, group.height, screen.height, margin.y),
    zoom,
  }
}

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

  return (
    !!viewport &&
    Number.isFinite(viewport.x) &&
    Number.isFinite(viewport.y) &&
    Number.isFinite(viewport.zoom) &&
    viewport.zoom > 0
  )
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
