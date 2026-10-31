import { STATUS_LABEL, type ViewStatus, type Who } from './model'

/**
 * The companion is the logo's three stars as a small creature that perches on whatever is nearest the pointer and
 * reacts to it. This module holds the parts that don't animate: what it perches on and what it says there.
 */

export type Mood = '' | 'wink' | 'impatient' | 'excited' | 'curious' | 'happy' | 'worried' | 'surprised' | 'sleepy'

export type Rect = { left: number; top: number; right: number; bottom: number }

/**
 * Something the companion can perch on, in the canvas's own pixels. `top` raises the perch above whatever sits over
 * the target, such as the header of the open group a card leads.
 */
export type PerchTarget = { id: string; rect: Rect; top?: number }

/** A picture and a word or two, never a sentence. */
export type Hint = { text: string; status?: ViewStatus; mood: Mood }

/** A perch has to show at least this much of itself before the companion lands on it. */
export const MIN_VISIBLE = 24
/** A new neighbor has to be this much closer than the current perch to take over, which keeps it from flickering. */
export const SWITCH_MARGIN = 40

const MOODS: Record<ViewStatus, Mood> = {
  ready: 'excited',
  active: '',
  review: 'curious',
  blocked: 'worried',
  deferred: '',
  done: 'happy',
}

/** What the companion says about a card, from its derived status and whose move it is. */
export function describeCard(status: ViewStatus, who?: Who): Hint {
  if (who === 'you' && status !== 'done') return { text: 'Your move', status, mood: 'wink' }

  if (who === 'review' && status !== 'done') return { text: STATUS_LABEL.review, status: 'review', mood: 'curious' }

  return { text: STATUS_LABEL[status], status, mood: MOODS[status] }
}

/** The part of a rectangle inside a width by height view, or null when too little of it shows to perch on. */
export function clipRect(rect: Rect, width: number, height: number): Rect | null {
  const clipped = {
    left: Math.max(rect.left, 0),
    top: Math.max(rect.top, 0),
    right: Math.min(rect.right, width),
    bottom: Math.min(rect.bottom, height),
  }

  return clipped.right - clipped.left > MIN_VISIBLE && clipped.bottom - clipped.top > MIN_VISIBLE ? clipped : null
}

const distanceTo = (rect: Rect, x: number, y: number) =>
  Math.hypot(Math.max(rect.left - x, 0, x - rect.right), Math.max(rect.top - y, 0, y - rect.bottom))

/**
 * Picks the perch nearest the pointer, so the companion stays nearby instead of flying home whenever the pointer
 * crosses a gap. Targets must already be clipped to the view. Returns the current perch's id while it still shows and
 * nothing is clearly closer, and null when nothing shows.
 */
export function pickPerch(
  targets: readonly PerchTarget[],
  x: number,
  y: number,
  current: string | null,
): string | null {
  let best: PerchTarget | null = null
  let bestDistance = Infinity
  let currentDistance = Infinity

  for (const target of targets) {
    const distance = distanceTo(target.rect, x, y)

    if (target.id === current) currentDistance = distance

    if (distance < bestDistance) {
      best = target
      bestDistance = distance
    }
  }

  if (!best) return null

  if (currentDistance === Infinity) return best.id

  return bestDistance < currentDistance - SWITCH_MARGIN ? best.id : current
}
