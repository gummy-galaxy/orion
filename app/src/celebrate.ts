import { isTask, type AppNode, type Link, type TaskData } from './model'

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

/** How long the flourish on a chain's last beat runs once its Done stamp lands. `motion.duration.flourish` overrides it. */
export const FLOURISH_MS = 640

/**
 * Finished cards connected to `startId` through blocking links, each with the hops it takes to reach it.
 * The walk runs both ways and passes only through finished cards, so related links and open work stop it.
 */
export function finishedHops(startId: string, links: Link[], isFinished: (id: string) => boolean): Map<string, number> {
  const neighbors = new Map<string, string[]>()

  for (const link of links) {
    if (link.kind !== 'blocks') continue

    neighbors.set(link.from, [...(neighbors.get(link.from) ?? []), link.to])
    neighbors.set(link.to, [...(neighbors.get(link.to) ?? []), link.from])
  }

  const hops = new Map<string, number>([[startId, 0]])
  const queue = [startId]

  for (let index = 0; index < queue.length; index++) {
    const current = queue[index]
    const distance = hops.get(current)!

    for (const next of neighbors.get(current) ?? []) {
      if (hops.has(next) || !isFinished(next)) continue

      hops.set(next, distance + 1)
      queue.push(next)
    }
  }

  return hops
}

/** The delay before the stamp a number of hops from the click starts clearing, following the chain's beats. */
function chainDelay(hops: number, stepMs = CHAIN_STEP_MS): number {
  const finale = CHAIN_BEATS_MS.length - 1
  const capped = Math.min(hops, MAX_HOPS)

  if (capped <= finale) return CHAIN_BEATS_MS[capped]

  return CHAIN_BEATS_MS[finale] + (capped - finale) * stepMs
}

/**
 * The waiting cards a click on `startId` clears, each with the delay before its stamp starts clearing.
 * Empty unless the clicked card is itself waiting. Cards without the flag are never included.
 */
export function celebrationDelays(
  startId: string,
  nodes: AppNode[],
  links: Link[],
  isFinished: (id: string) => boolean,
  stepMs = CHAIN_STEP_MS,
): Map<string, number> {
  const delays = new Map<string, number>()
  const byId = new Map(nodes.map((node) => [node.id, node]))
  const start = byId.get(startId)

  if (!start || !isTask(start) || !start.data.celebrate) return delays

  for (const [id, delay] of chainBeats(startId, links, isFinished, stepMs)) {
    const node = byId.get(id)

    if (node && isTask(node) && node.data.celebrate) delays.set(id, delay)
  }

  return delays
}

/**
 * The beat every finished card the chain from `startId` reaches lands on, including cards closed out before that the
 * chain only passes through, so a pulse can cross them.
 */
export function chainBeats(startId: string, links: Link[], isFinished: (id: string) => boolean, stepMs = CHAIN_STEP_MS): Map<string, number> {
  const beats = new Map<string, number>()

  for (const [id, hops] of finishedHops(startId, links, isFinished)) beats.set(id, chainDelay(hops, stepMs))

  return beats
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

    if (link.kind !== 'blocks' || from === undefined || to === undefined || from === to || Math.max(from, to) > untilMs) continue

    pulses.set(link.id, { delayMs: Math.min(from, to), durationMs: Math.abs(to - from), reverse: to < from })
  }

  return pulses
}

/** The cards on a chain's last beat, which close it out with a flourish so even a chain of two resolves. */
export function chainFinale(delays: ReadonlyMap<string, number>): Set<string> {
  const last = Math.max(...delays.values())

  return new Set([...delays].filter(([, delay]) => delay === last).map(([id]) => id))
}

/** Clears the celebrate flag on the given cards. Other cards are returned as they were. */
export function clearCelebrations(nodes: AppNode[], ids: ReadonlySet<string>): AppNode[] {
  return nodes.map((node) => {
    if (!isTask(node) || !ids.has(node.id) || !node.data.celebrate) return node

    const { celebrate: _celebrate, ...data } = node.data

    return { ...node, data }
  })
}

/**
 * A card's data after a patch. Finishing a card in the app closes it out at once, so a change to done sets the flag
 * to false, which the CLI store reads as closed out and drops instead of leaving the card waiting. A change away from
 * done clears it. Notes never get the flag.
 */
export function patchTaskData(data: TaskData, patch: Partial<TaskData>): TaskData {
  const next: TaskData = { ...data, ...patch }
  const changed = patch.status !== undefined && patch.status !== data.status

  if (!changed || next.itemKind === 'note') return next

  if (next.status === 'done') next.celebrate = false
  else delete next.celebrate

  return next
}

/** Whether a patch finishes a card in the app. Those close out at once, so their Done stamp lands right away. */
export function closesOut(data: TaskData, patch: Partial<TaskData>): boolean {
  const kind = patch.itemKind ?? data.itemKind

  return patch.status === 'done' && data.status !== 'done' && kind !== 'note' && kind !== 'component'
}
