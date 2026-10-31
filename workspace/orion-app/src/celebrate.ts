import { getCardType } from './cardTypes/getCardType'
import { getStateMeaning } from './cardTypes/getStateMeaning'
import type { Link, TaskData } from './model'

/**
 * When, in milliseconds after the click, each beat of a chain starts its stamp clearing: the clicked card, then the
 * first three hops. The gaps climb a little toward the third hop, the finale, which holds slightly longer.
 */
export const CHAIN_BEATS_MS = [150, 500, 850, 1250]

/** How far apart each hop past the finale starts, without climbing further. `motion.duration.chain` overrides it. */
export const CHAIN_STEP_MS = 300

/** Chains stop spreading after this many hops, so a long chain still finishes in about three seconds. */
const MAX_HOPS = 8

/** How long one stamp's clearing animation runs. `motion.duration.clear` overrides it, in the CSS too. */
export const CLEAR_MS = 420

/** How long after its stamp starts clearing a card's Done stamp starts landing. `motion.duration.fade` overrides it. */
export const FADE_MS = 180

/** How long a Done stamp takes to land. `motion.duration.stamp` overrides it. */
export const STAMP_MS = 360

/**
 * How long the flourish on a chain's last beat runs once its Done stamp lands. `motion.duration.flourish` overrides it.
 */
export const FLOURISH_MS = 640

/** The delay before the stamp a number of hops from the click starts clearing, following the chain's beats. */
export function chainDelay(hops: number, stepMs = CHAIN_STEP_MS): number {
  const finale = CHAIN_BEATS_MS.length - 1
  const capped = Math.min(hops, MAX_HOPS)

  if (capped <= finale) return CHAIN_BEATS_MS[capped]

  return CHAIN_BEATS_MS[finale] + (capped - finale) * stepMs
}

/** A card a chain close reached, and how many blocking links it is from the card clicked. */
export type ChainStep = { id: string; hops: number }

/**
 * What `orion serve` answers a chain close with: the cards it closed out, starting with the one clicked, and the
 * finished cards the chain passed through that weren't waiting.
 */
export type ChainAnswer = { closed: ChainStep[]; passed: ChainStep[] }

/** When each card on a closing chain lands its stamp, in milliseconds from when the server's answer arrived. */
export type ChainTiming = {
  /** Every card the chain reached, closed out or passed through, so a pulse can cross them all. */
  beats: Map<string, number>
  /** The cards closed out, the clicked one included. */
  closed: Map<string, number>
}

/**
 * Times a chain from the server's answer, which arrived `elapsedMs` after the click. The clicked card stamped at the
 * click, so its beat may already be past. The rest keep their beats, and an answer later than the first of them pushes
 * them all back together, so a slow answer delays only the cards after the first and keeps their rhythm.
 */
export function timeChain(answer: ChainAnswer, elapsedMs: number, stepMs = CHAIN_STEP_MS): ChainTiming {
  const late = Math.max(0, elapsedMs - chainDelay(1, stepMs))
  const at = (hops: number) => chainDelay(hops, stepMs) + (hops > 0 ? late : 0) - elapsedMs
  const closed = new Map(answer.closed.map((step) => [step.id, at(step.hops)]))
  const beats = new Map([...closed, ...answer.passed.map((step): [string, number] => [step.id, at(step.hops)])])

  return { beats, closed }
}

/** A pulse running along a link from one card's beat to the next card's, so the eye follows the chain. */
export type Pulse = {
  /** When the pulse leaves, in milliseconds after the click: the beat of the card it starts from. */
  delayMs: number
  /** How long it takes to reach the next card, which is the gap until that card's beat. */
  durationMs: number
  /** Whether it runs against the link, from the card the link points at back to the card it leaves. */
  reverse: boolean
}

/**
 * The pulses for a chain closing out, keyed by link id: one along each blocking link between two cards on different
 * beats, running from the earlier beat to the later one. Cards on the same beat, such as hops past the cap, get none,
 * and the pulses stop at the chain's last beat, `untilMs`, rather than running on through work closed out before.
 */
export function chainPulses(beats: ReadonlyMap<string, number>, links: Link[], untilMs: number): Map<string, Pulse> {
  const pulses = new Map<string, Pulse>()

  for (const link of links) {
    const from = beats.get(link.from)
    const to = beats.get(link.to)

    if (link.kind !== 'blocks' || from === undefined || to === undefined || from === to || Math.max(from, to) > untilMs)
      continue

    pulses.set(link.id, { delayMs: Math.min(from, to), durationMs: Math.abs(to - from), reverse: to < from })
  }

  return pulses
}

/**
 * The cards on a chain's last beat, with that beat, which close it out with a flourish so even a chain of two resolves.
 */
export function chainFinale(delays: ReadonlyMap<string, number>): Map<string, number> {
  const last = Math.max(...delays.values())

  return new Map([...delays].filter(([, delay]) => delay === last))
}

/** Whether a patch finishes a card in the app. Those close out at once, so their Done stamp lands right away. */
export function closesOut(data: TaskData, patch: Partial<TaskData>): boolean {
  const after = { ...data, ...patch }

  return (
    patch.status !== undefined &&
    getStateMeaning(after) === 'done' &&
    getStateMeaning(data) !== 'done' &&
    getCardType(after).meaning.isWork
  )
}
