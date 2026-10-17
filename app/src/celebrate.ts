import { isTask, type AppNode, type Link, type TaskData } from './model'

/** How far apart, in milliseconds, each hop down a chain starts its stamp clearing. */
export const CHAIN_STEP_MS = 90

/** Chains stop spreading after this many hops, so a long chain still clears in about a second. */
const MAX_HOPS = 8

/** How long one stamp's clearing animation runs. The CSS uses the same duration. */
export const CLEAR_MS = 420

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

/**
 * The waiting cards a click on `startId` clears, each with the delay before its stamp starts clearing.
 * Empty unless the clicked card is itself waiting. Cards without the flag are never included.
 */
export function celebrationDelays(startId: string, nodes: AppNode[], links: Link[], isFinished: (id: string) => boolean): Map<string, number> {
  const delays = new Map<string, number>()
  const byId = new Map(nodes.map((node) => [node.id, node]))
  const start = byId.get(startId)

  if (!start || !isTask(start) || !start.data.celebrate) return delays

  for (const [id, hops] of finishedHops(startId, links, isFinished)) {
    const node = byId.get(id)

    if (node && isTask(node) && node.data.celebrate) delays.set(id, Math.min(hops, MAX_HOPS) * CHAIN_STEP_MS)
  }

  return delays
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
