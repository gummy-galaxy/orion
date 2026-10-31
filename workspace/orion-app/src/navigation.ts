import type { Viewport } from '@xyflow/react'

/** Where the canvas was: the open group, the card in focus, what was selected, and the view. */
export type Place<Extra = unknown> = {
  root: string | null
  focus: string | null
  selected: string[]
  viewport: Viewport
  /** Anything else the canvas needs to put the place back as it was. */
  extra?: Extra
}
export type Trail<Extra = unknown> = { back: Place<Extra>[]; forward: Place<Extra>[] }

export const TRAIL_LIMIT = 50
/**
 * The desktop shell dispatches this on `window`, with `back` or `forward` as its detail, for the mouse's side buttons.
 */
export const NAVIGATE_EVENT = 'orion:navigate'
/** Views closer than this, in screen pixels and zoom, count as the same place. */
const NEAR_PX = 2
const NEAR_ZOOM = 0.001

export const emptyTrail = <Extra>(): Trail<Extra> => ({ back: [], forward: [] })

export function samePlace(a: Place, b: Place): boolean {
  return (
    a.root === b.root &&
    a.focus === b.focus &&
    a.selected.join(',') === b.selected.join(',') &&
    Math.abs(a.viewport.x - b.viewport.x) < NEAR_PX &&
    Math.abs(a.viewport.y - b.viewport.y) < NEAR_PX &&
    Math.abs(a.viewport.zoom - b.viewport.zoom) < NEAR_ZOOM
  )
}

/** Leaving `from` for somewhere new puts it on the back stack and drops the forward one, as in a browser. */
export function leave<Extra>(trail: Trail<Extra>, from: Place<Extra>, limit = TRAIL_LIMIT): Trail<Extra> {
  const last = trail.back.at(-1)

  if (last && samePlace(last, from)) return { back: trail.back, forward: [] }

  return { back: [...trail.back, from].slice(-limit), forward: [] }
}

/** Moves from `here` to the nearest place in `direction` that still `exists`, dropping any that don't. */
export function travel<Extra>(
  trail: Trail<Extra>,
  here: Place<Extra>,
  direction: 'back' | 'forward',
  exists: (place: Place<Extra>) => boolean,
): { trail: Trail<Extra>; place: Place<Extra> } | null {
  const ahead = direction === 'back' ? trail.back : trail.forward
  let index = ahead.length - 1

  while (index >= 0 && !exists(ahead[index])) index--

  if (index < 0) return null

  const rest = ahead.slice(0, index)
  const behind = [...(direction === 'back' ? trail.forward : trail.back), here]

  return {
    place: ahead[index],
    trail: direction === 'back' ? { back: rest, forward: behind } : { back: behind, forward: rest },
  }
}
