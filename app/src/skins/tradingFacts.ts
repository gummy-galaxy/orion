import type { CardSizeLabel, CardView, Priority } from '../cardView'
import type { Rarity } from '../rarity'

/** One status that asks a person to act, most urgent first. */
export const STICKERS = ['conflict', 'failing', 'changes', 'stale', 'mergeable'] as const
/** Work running without anyone, shown until it lands. */
export const MOTIONS = ['running', 'queued'] as const

export type Sticker = (typeof STICKERS)[number]
export type Motion = (typeof MOTIONS)[number]

/** Rarity's finish: uncommon cards get a silver rim, rare cards a foil rim, and mythic cards foil and holo. */
export type Finish = 'silver' | 'foil' | 'holo'

export type TradingFacts = {
  priority?: Priority
  finish?: Finish
  size?: CardSizeLabel
  sticker?: Sticker
  motion?: Motion
  locked: boolean
  blockers: number
  unblocks: number
  hue: number
  /** Where the kind's emblem sits in the art, from -1 to 1, seeded by the card so neighbors differ. */
  shift: number
  /** Seeds the card's scene, so it draws the same each time. */
  seed: number
}

/** A pull request with no change in this long reads as stale. */
export const STALE_DAYS = 14
/** Art palettes in `trading.css`, picked per group. */
export const HUES = 5

const FINISH_BY_RARITY: Record<Rarity, Finish | undefined> = { common: undefined, uncommon: 'silver', rare: 'foil', mythic: 'holo' }

const DAY_MS = 24 * 60 * 60 * 1000

// FNV-1a, so a group keeps its palette across sessions.
function hashText(value: string): number {
  let hash = 2166136261

  for (let index = 0; index < value.length; index++) {
    hash ^= value.charCodeAt(index)
    hash = Math.imul(hash, 16777619)
  }

  return hash >>> 0
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

export function getTradingFacts(view: CardView, now = Date.now()): TradingFacts {
  const settled = view.status === 'done' || view.status === 'deferred'
  const sticker = settled ? undefined : getSticker(view, now)
  const motion = settled ? undefined : getMotion(view)
  const finish = settled || !view.rarity ? undefined : FINISH_BY_RARITY[view.rarity]

  return {
    ...(view.priority !== undefined ? { priority: view.priority } : {}),
    ...(finish ? { finish } : {}),
    ...(view.size ? { size: view.size } : {}),
    ...(sticker ? { sticker } : {}),
    ...(motion ? { motion } : {}),
    locked: view.status === 'blocked',
    blockers: view.blockers ?? 0,
    unblocks: view.unblocks ?? 0,
    hue: view.group ? hashText(view.group) % HUES : 0,
    shift: ((hashText(view.artSeed) % 201) - 100) / 100,
    seed: hashText(view.artSeed),
  }
}
