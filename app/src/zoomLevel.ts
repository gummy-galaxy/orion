/** Zoom below which cards draw their compact form and related links stop drawing. The debug bar tunes it live. */
export const DEFAULT_COMPACT_ZOOM = 0.3

export type ZoomLevel = 'full' | 'compact'

let compactZoom = DEFAULT_COMPACT_ZOOM
const listeners = new Set<() => void>()

export function getCompactZoom() {
  return compactZoom
}

/** Ignores anything that isn't a positive number, so a half-typed value in the debug bar can't break the canvas. */
export function setCompactZoom(next: number) {
  if (!Number.isFinite(next) || next <= 0) return

  compactZoom = next

  for (const listener of listeners) listener()
}

export function subscribeCompactZoom(listener: () => void) {
  listeners.add(listener)

  return () => void listeners.delete(listener)
}

export function zoomLevel(zoom: number): ZoomLevel {
  return zoom < compactZoom ? 'compact' : 'full'
}
