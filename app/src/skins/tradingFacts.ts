import type { CardSizeLabel, CardView, Priority } from '../cardView'
import type { Rarity } from '../rarity'
import { hashText, INK, type InkPair } from './frameColor'

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
  inks: InkPair
  /** Where the kind's emblem sits in the art, from -1 to 1, seeded by the card so neighbors differ. */
  shift: number
  /** Seeds the card's scene, so it draws the same each time. */
  seed: number
}

/** What each mark on a trading card means, for its tooltips and the details view. */
export const STICKER_HINT: Record<Sticker, string> = {
  conflict: 'The pull request has merge conflicts',
  failing: 'Checks are failing',
  changes: 'A review asked for changes',
  stale: 'No change in a while',
  mergeable: 'Ready to merge',
}

export const KIND_HINT: Record<CardView['kind'], string> = {
  step: 'Step',
  pr: 'Pull request',
  placeholder: 'Expected pull request',
  gate: 'Gate',
  note: 'Note',
}

export const MOTION_HINT: Record<Motion, string> = {
  running: 'Checks are running',
  queued: 'Checks are queued',
}

/** A pull request with no change in this long reads as stale. */
export const STALE_DAYS = 14
/** Art palettes in `trading.css`, picked per group. */
export const HUES = 5

/** The inks of each palette, for art drawn outside CSS. They match `--trading-ink-one` and `--trading-ink-two`. */
const HUE_INKS: InkPair[] = [
  [INK.violet, INK.pink],
  [INK.blue, '#7af0e0'],
  ['#ff8f3d', INK.magenta],
  [INK.teal, INK.blue],
  [INK.magenta, INK.gold],
]

const FINISH_BY_RARITY: Record<Rarity, Finish | undefined> = { common: undefined, uncommon: 'silver', rare: 'foil', mythic: 'holo' }

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

export function getTradingFacts(view: CardView, now = Date.now()): TradingFacts {
  const settled = view.status === 'done' || view.status === 'deferred'
  const sticker = settled ? undefined : getSticker(view, now)
  const motion = settled ? undefined : getMotion(view)
  // FNV-1a, so a group keeps its palette across sessions.
  const hue = view.group ? hashText(view.group) % HUES : 0
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
    hue,
    inks: HUE_INKS[hue],
    shift: ((hashText(view.artSeed) % 201) - 100) / 100,
    seed: hashText(view.artSeed),
  }
}
