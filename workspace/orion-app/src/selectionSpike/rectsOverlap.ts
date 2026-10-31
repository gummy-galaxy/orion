import type { Rect } from './types'

/** Whether two rectangles overlap once each is grown by `gap` on every side. */
export function rectsOverlap(a: Rect, b: Rect, gap = 0) {
  return a.x0 - gap < b.x1 && b.x0 - gap < a.x1 && a.y0 - gap < b.y1 && b.y0 - gap < a.y1
}
