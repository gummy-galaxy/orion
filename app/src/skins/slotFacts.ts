import type { CardSizeLabel, CardView, Priority } from '../cardView'
import { hashText } from './frameColor'

/** One status that asks a person to act, most urgent first. */
export const STICKERS = ['conflict', 'failing', 'changes', 'stale', 'mergeable'] as const
/** Work running without anyone, shown until it lands. */
export const MOTIONS = ['running', 'queued'] as const

export type Sticker = (typeof STICKERS)[number]
export type Motion = (typeof MOTIONS)[number]

export type SlotFacts = {
  priority?: Priority
  size?: CardSizeLabel
  sticker?: Sticker
  motion?: Motion
  locked: boolean
  blockers: number
  unblocks: number
  hue: number
}

/** A pull request with no change in this long reads as stale. */
export const STALE_DAYS = 14
/** Art palettes in `slots.css`, picked per group. */
export const HUES = 5

const DAY_MS = 24 * 60 * 60 * 1000

function getSticker(view: CardView, now: number): Sticker | undefined {
  if (view.readiness === 'conflict') return 'conflict'

  if (view.readiness === 'failing') return 'failing'

  if (view.changesRequested) return 'changes'

  if (view.kind === 'pr' && view.updatedAt && now - Date.parse(view.updatedAt) > STALE_DAYS * DAY_MS) return 'stale'

  if (view.readyToMerge) return 'mergeable'

  return undefined
}

function getMotion(view: CardView): Motion | undefined {
  if (view.readiness === 'running') return 'running'

  if (view.readiness === 'waiting') return 'queued'

  return undefined
}

export function getSlotFacts(view: CardView, now = Date.now()): SlotFacts {
  const settled = view.status === 'done' || view.status === 'deferred'
  const sticker = settled ? undefined : getSticker(view, now)
  const motion = settled ? undefined : getMotion(view)

  return {
    ...(view.priority !== undefined ? { priority: view.priority } : {}),
    ...(view.size ? { size: view.size } : {}),
    ...(sticker ? { sticker } : {}),
    ...(motion ? { motion } : {}),
    locked: view.status === 'blocked',
    blockers: view.blockers ?? 0,
    unblocks: view.unblocks ?? 0,
    hue: view.group ? hashText(view.group) % HUES : 0,
  }
}
