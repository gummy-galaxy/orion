import type { RowRange } from './types'

/** The rows a scrolled list of `count` same-height rows draws: those in view, plus `overscan` more on each side. */
export function getVisibleRange(scrollTop: number, viewportHeight: number, rowHeight: number, count: number, overscan: number): RowRange {
  const end = Math.min(count, Math.ceil((scrollTop + viewportHeight) / rowHeight) + overscan)
  const start = Math.max(0, Math.min(end, Math.floor(scrollTop / rowHeight) - overscan))

  return { start, end }
}
