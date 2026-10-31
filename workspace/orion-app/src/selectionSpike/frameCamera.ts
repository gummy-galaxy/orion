import type { Camera, Rect } from './types'

/** A camera that fits `rect` in a viewport of `width` by `height`, with room around it. */
export function frameCamera(rect: Rect, width: number, height: number, padding = 80): Camera {
  const zoom = Math.min(1, Math.max(0.15, Math.min((width - padding * 2) / (rect.x1 - rect.x0), (height - padding * 2) / (rect.y1 - rect.y0))))

  return {
    x: width / 2 - ((rect.x0 + rect.x1) / 2) * zoom,
    y: height / 2 - ((rect.y0 + rect.y1) / 2) * zoom,
    zoom,
  }
}
