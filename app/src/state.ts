import { atom, useAtomValue } from 'jotai'
import { selectAtom } from 'jotai/utils'
import { useMemo } from 'react'
import { deriveWork, traceFrom, type AttentionMark, type GroupStats } from './derive'
import { isTask, type AppNode, type Link } from './model'
import type { Badge } from './sources'

export const nodesAtom = atom<AppNode[]>([])
export const linksAtom = atom<Link[]>([])
export const githubOwnerAtom = atom('flipbook-labs')
export const hoverAtom = atom<string | null>(null)
/** A double-clicked card keeps its trace while you pan around; any click lets it go. */
export const pinnedAtom = atom<string | null>(null)

export const workAtom = atom((get) => deriveWork(get(nodesAtom), get(linksAtom), get(githubOwnerAtom)))

export const traceAtom = atom((get) => {
  const from = get(pinnedAtom) ?? get(hoverAtom)
  const nodes = get(nodesAtom)
  const h = from ? nodes.find((n) => n.id === from) : undefined
  if (!h || !isTask(h)) return null
  const { preds, succs } = get(workAtom)
  const related = get(linksAtom)
    .filter((l) => l.kind === 'related' && (l.from === h.id || l.to === h.id))
    .map((l) => (l.from === h.id ? l.to : l.from))
  return traceFrom(
    h.id,
    preds,
    succs,
    nodes.filter(isTask).map((n) => n.id),
    related,
  )
})

// The canvas works these out from the viewport and hands them over each render.
export const collapsedAtom = atom<Set<string>>(new Set<string>())
/** Zoomed out far enough that cards and notes show their details at one on-screen size. */
export const farAtom = atom(false)
/** While ⌘ is held: what needs you, keyed by the card or folded group that shows it. */
export const attentionAtom = atom<Map<string, AttentionMark> | null>(null)

const NO_STATS: GroupStats = { total: 0, done: 0, ready: 0, blocked: 0, outside: 0 }
const NO_SOURCES: Badge[] = []

const sameStats = (a: GroupStats, b: GroupStats) =>
  a.total === b.total && a.done === b.done && a.ready === b.ready && a.blocked === b.blocked && a.outside === b.outside

const sameSources = (a: Badge[], b: Badge[]) =>
  a.length === b.length && a.every((x, i) => x.icon === b[i].icon && x.domain === b[i].domain && x.label === b[i].label && x.href === b[i].href)

// Each hook below reads one card's part, so a card redraws only when its own part changes.

export const useStatus = (id: string) => useAtomValue(useMemo(() => selectAtom(workAtom, (w) => w.status.get(id) ?? 'ready'), [id]))

export const useLeverage = (id: string) => useAtomValue(useMemo(() => selectAtom(workAtom, (w) => w.leverage.get(id) ?? 0), [id]))

export const useGroupStats = (id: string) => useAtomValue(useMemo(() => selectAtom(workAtom, (w) => w.groups.get(id) ?? NO_STATS, sameStats), [id]))

export const useSources = (id: string) => useAtomValue(useMemo(() => selectAtom(workAtom, (w) => w.sources.get(id) ?? NO_SOURCES, sameSources), [id]))

/** Dimming comes from the canvas while a trace shows, so cards outside it don't redraw as the trace moves. */
export const useTraceRole = (id: string) =>
  useAtomValue(
    useMemo(
      () =>
        selectAtom(traceAtom, (t) => {
          const role = t?.get(id)
          return role === 'dim' ? undefined : role
        }),
      [id],
    ),
  )

export const useMarked = (id: string) => useAtomValue(useMemo(() => selectAtom(attentionAtom, (a) => !!a?.has(id)), [id]))

export const useCollapsed = (id: string) => useAtomValue(useMemo(() => selectAtom(collapsedAtom, (c) => c.has(id)), [id]))

export const useFar = () => useAtomValue(farAtom)
