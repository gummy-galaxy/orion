import type { CardSizeLabel, CardView, Priority } from '../cardView'
import { hashText } from './frameColor'

/** One status that asks a person to act, most urgent first. */
export const STICKERS = ['conflict', 'failing', 'changes', 'stale', 'mergeable'] as const
/** Work running without anyone, shown until it lands. */
export const MOTIONS = ['running', 'queued'] as const

export type Sticker = (typeof STICKERS)[number]
export type Motion = (typeof MOTIONS)[number]
export type SlotFact<T> = { value: T; estimated: boolean }

export type SlotFacts = {
  priority?: SlotFact<Priority>
  size?: SlotFact<CardSizeLabel>
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

// Cards that unlock a lot of open work earn a provisional priority until a source sets one.
function estimatePriority(leverage: number): Priority | undefined {
  if (leverage >= 6) return 1

  if (leverage >= 3) return 2

  return undefined
}

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
  const estimate = settled ? undefined : estimatePriority(view.leverage)
  const priority =
    view.priority !== undefined
      ? { value: view.priority, estimated: false }
      : estimate !== undefined
        ? { value: estimate, estimated: true }
        : undefined
  const sticker = settled ? undefined : getSticker(view, now)
  const motion = settled ? undefined : getMotion(view)

  return {
    ...(priority ? { priority } : {}),
    ...(view.size ? { size: { value: view.size, estimated: false } } : {}),
    ...(sticker ? { sticker } : {}),
    ...(motion ? { motion } : {}),
    locked: view.status === 'blocked',
    blockers: view.blockers ?? 0,
    unblocks: view.unblocks ?? 0,
    hue: view.group ? hashText(view.group) % HUES : 0,
  }
}
