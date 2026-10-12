/**
 * How much nesting the canvas shows below the open group, as a number of levels: 1 folds every group in view into
 * a single body, and each level above opens one more layer of groups inside. Unset shows everything.
 */
export type Detail = number | null

type DetailStore = Pick<Storage, 'getItem' | 'setItem'>

/** Detail is this device's view state, like the viewport, so it stays out of orion.json. */
const KEY = 'orion:detail:'
/** Stored for every level, since nothing stored means the default. */
const EVERY_LEVEL = 'all'

/** A canvas starts with its groups folded, so a big one doesn't draw every card at once. */
export const DEFAULT_DETAIL: Detail = 1

const browserStore = (): DetailStore | null => {
  try {
    return localStorage
  } catch {
    return null
  }
}

/** Levels there are to show for groups at these depths below the open group; one more than the deepest opens them all. */
export function detailLevels(depths: number[]): number {
  return depths.length ? Math.max(...depths) + 2 : 1
}

/** The level showing, which is every level when detail is unset or above what there is. */
export function shownLevel(detail: Detail, levels: number): number {
  return Math.max(1, Math.min(detail ?? levels, levels))
}

/** Groups at this depth below the open group, or deeper, fold into single bodies. */
export function foldDepth(detail: Detail, levels: number): number {
  return shownLevel(detail, levels) - 1
}

/** One level less or more detail. Reaching every level unsets it, so groups nested deeper later show open too. */
export function stepDetail(detail: Detail, levels: number, direction: -1 | 1): Detail {
  const next = Math.max(1, Math.min(shownLevel(detail, levels) + direction, levels))

  return next >= levels ? null : next
}

export function readDetail(workspace: string, store = browserStore()): Detail {
  try {
    const stored = store?.getItem(KEY + workspace)

    if (stored === EVERY_LEVEL) return null

    const value = Number(stored)

    return stored && Number.isInteger(value) && value >= 1 ? value : DEFAULT_DETAIL
  } catch {
    return DEFAULT_DETAIL
  }
}

export function writeDetail(workspace: string, detail: Detail, store = browserStore()) {
  try {
    store?.setItem(KEY + workspace, detail === null ? EVERY_LEVEL : String(detail))
  } catch {
    // Only a remembered view.
  }
}
