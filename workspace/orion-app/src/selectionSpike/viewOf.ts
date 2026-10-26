import type { Camera, Rect } from './types'

/** The part of the board a camera shows in a viewport of the given size. */
export function viewOf(camera: Camera, size: { width: number; height: number }): Rect {
  return {
    x0: -camera.x / camera.zoom,
    y0: -camera.y / camera.zoom,
    x1: (size.width - camera.x) / camera.zoom,
    y1: (size.height - camera.y) / camera.zoom,
  }
}
