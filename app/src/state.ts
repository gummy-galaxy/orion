import { atom, getDefaultStore, useAtomValue } from 'jotai'
import { selectAtom } from 'jotai/utils'
import { useMemo } from 'react'
import { getCardView } from './cardView'
import { readAppearance } from './appearance'
import { deriveWork, traceFrom, type AttentionMark, type GroupStats, type SourceRef } from './derive'
import { isTask, type AppNode, type Link, type TaskNode, type ViewStatus } from './model'

export const nodesAtom = atom<AppNode[]>([])
export const skinAtom = atom(readAppearance().skin)
// The skin lives in Jotai's default store because this per-device preference is shared by every canvas and story store.
export const skinStore = getDefaultStore()
export const linksAtom = atom<Link[]>([])
export const hoverAtom = atom<string | null>(null)
/** A double-clicked card keeps its trace while you pan around; any click lets it go. */
export const pinnedAtom = atom<string | null>(null)
/** While a card is in focus, nothing traces from the cursor. */
export const focusedAtom = atom(false)

export const workAtom = atom((get) => deriveWork(get(nodesAtom), get(linksAtom)))

export const traceAtom = atom((get) => {
  const from = get(focusedAtom) ? null : (get(pinnedAtom) ?? get(hoverAtom))
  const nodes = get(nodesAtom)
  const tracedNode = from ? nodes.find((node) => node.id === from) : undefined

  if (!tracedNode || !isTask(tracedNode)) return null

  const { preds: predecessors, succs: successors } = get(workAtom)
  const related = get(linksAtom)
    .filter((link) => link.kind === 'related' && (link.from === tracedNode.id || link.to === tracedNode.id))
    .map((link) => (link.from === tracedNode.id ? link.to : link.from))

  return traceFrom(
    tracedNode.id,
    predecessors,
    successors,
    nodes.filter(isTask).map((node) => node.id),
    related,
  )
})

// The canvas works these out from the viewport and hands them over each render.
export const collapsedAtom = atom<Set<string>>(new Set<string>())
/** While ⌘ is held: what needs you, keyed by the card or folded group that shows it. */
export const attentionAtom = atom<Map<string, AttentionMark> | null>(null)
/** While Ctrl is held, inspect mode shows more about what's on the canvas, such as the hovered card in full. */
export const inspectingAtom = atom(false)

const NO_STATS: GroupStats = { total: 0, done: 0, ready: 0, blocked: 0, outside: 0 }
const NO_SOURCES: SourceRef[] = []

const sameStats = (a: GroupStats, b: GroupStats) =>
  a.total === b.total && a.done === b.done && a.ready === b.ready && a.blocked === b.blocked && a.outside === b.outside

const sameSources = (a: SourceRef[], b: SourceRef[]) =>
  a.length === b.length && a.every((source, i) => source.domain === b[i].domain && source.label === b[i].label && source.href === b[i].href)

// Each hook below reads one card's part, so a card redraws only when its own part changes.

export const useStatus = (id: string) => useAtomValue(useMemo(() => selectAtom(workAtom, (work) => work.status.get(id) ?? 'ready'), [id]))

export const useLeverage = (id: string) => useAtomValue(useMemo(() => selectAtom(workAtom, (work) => work.leverage.get(id) ?? 0), [id]))

export const useUpstream = (id: string) => useAtomValue(useMemo(() => selectAtom(workAtom, (work) => work.upstream.get(id) ?? 0), [id]))

export const useGroupStats = (id: string) =>
  useAtomValue(useMemo(() => selectAtom(workAtom, (work) => work.groups.get(id) ?? NO_STATS, sameStats), [id]))

export const useSources = (id: string) =>
  useAtomValue(useMemo(() => selectAtom(workAtom, (work) => work.sources.get(id) ?? NO_SOURCES, sameSources), [id]))

const countOpen = (ids: string[] | undefined, status: Map<string, ViewStatus>) => (ids ?? []).filter((other) => status.get(other) !== 'done').length

export const useBlockers = (id: string) =>
  useAtomValue(useMemo(() => selectAtom(workAtom, (work) => countOpen(work.preds.get(id), work.status)), [id]))

export const useUnblocks = (id: string) =>
  useAtomValue(useMemo(() => selectAtom(workAtom, (work) => countOpen(work.succs.get(id), work.status)), [id]))

export function useCardView(id: string, data: TaskNode['data'], group?: string) {
  const status = useStatus(id)
  const leverage = useLeverage(id)
  const upstream = useUpstream(id)
  const sources = useSources(id)
  const blockers = useBlockers(id)
  const unblocks = useUnblocks(id)

  return useMemo(
    () => getCardView({ id, type: 'task', position: { x: 0, y: 0 }, data }, { status, leverage, upstream, sources, blockers, unblocks, group }),
    [id, data, status, leverage, upstream, sources, blockers, unblocks, group],
  )
}

/** Dimming comes from the canvas while a trace shows, so cards outside it don't redraw as the trace moves. */
export const useTraceRole = (id: string) =>
  useAtomValue(
    useMemo(
      () =>
        selectAtom(traceAtom, (trace) => {
          const role = trace?.get(id)

          return role === 'dim' ? undefined : role
        }),
      [id],
    ),
  )

export const useMarked = (id: string) => useAtomValue(useMemo(() => selectAtom(attentionAtom, (attention) => !!attention?.has(id)), [id]))

export const useCollapsed = (id: string) => useAtomValue(useMemo(() => selectAtom(collapsedAtom, (collapsed) => collapsed.has(id)), [id]))
