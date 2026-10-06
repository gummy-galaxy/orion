/**
 * Focus on one card: the canvas zooms onto it, and everything it waits on and
 * leads to lines up in scrolling columns on either side, wired into its edges.
 */
import { useCallback, useLayoutEffect, useRef, useState, type ReactNode } from 'react'
import type { Rect } from './attention'
import { STATUS_LABEL, type ViewStatus } from './model'

/** Lines from cards scrolled out of a column stop this far inside its edge. */
const CLIP_INSET = 6
const DETAILS_GAP = 24
/** Room kept clear at the top for the bar with the way back. */
const DETAILS_TOP = 64
const DETAILS_MIN_W = 300
const DETAILS_MAX_W = 440
const DETAILS_MIN_H = 160

export type FocusItem = {
  id: string
  label: string
  tag: string
  status: ViewStatus
  where: string
  related: boolean
  /** The link still blocks: it comes from open work. */
  live: boolean
}

type Anchor = { x: number; y: number; clipped: boolean }

const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v))

function curve(a: { x: number; y: number }, b: { x: number; y: number }) {
  const dx = Math.max(40, Math.abs(b.x - a.x) / 2)
  return `M${a.x},${a.y} C${a.x + dx},${a.y} ${b.x - dx},${b.y} ${b.x},${b.y}`
}

export function FocusView({
  label,
  card,
  sideWidth,
  inset,
  incoming,
  outgoing,
  onFocus,
  onExit,
  children,
}: {
  label: string
  /** The focused card on screen, relative to the canvas. */
  card: Rect
  sideWidth: number
  inset: number
  incoming: FocusItem[]
  outgoing: FocusItem[]
  onFocus: (id: string) => void
  onExit: () => void
  /** The card's details, shown above it. */
  children?: ReactNode
}) {
  const root = useRef<HTMLDivElement>(null)
  const [size, setSize] = useState({ w: 0, h: 0 })
  const [anchors, setAnchors] = useState<Map<string, Anchor>>(() => new Map())
  const [hot, setHot] = useState<string | null>(null)

  const measure = useCallback(() => {
    const el = root.current
    if (!el) return
    const box = el.getBoundingClientRect()
    const next = new Map<string, Anchor>()
    for (const list of el.querySelectorAll<HTMLElement>('.focus-list')) {
      const bounds = list.getBoundingClientRect()
      for (const item of list.querySelectorAll<HTMLElement>('[data-key]')) {
        const r = item.getBoundingClientRect()
        const mid = r.top + r.height / 2
        const y = clamp(mid, bounds.top + CLIP_INSET, bounds.bottom - CLIP_INSET)
        next.set(item.dataset.key!, { x: (item.dataset.side === 'in' ? r.right : r.left) - box.left, y: y - box.top, clipped: y !== mid })
      }
    }
    setSize({ w: box.width, h: box.height })
    setAnchors(next)
  }, [])

  useLayoutEffect(measure, [measure, incoming, outgoing])
  useLayoutEffect(() => {
    const el = root.current
    if (!el) return
    const observer = new ResizeObserver(measure)
    observer.observe(el)
    return () => observer.disconnect()
  }, [measure])

  const lines = [
    ...incoming.map((item) => ({ item, key: `in:${item.id}`, side: 'in' as const })),
    ...outgoing.map((item) => ({ item, key: `out:${item.id}`, side: 'out' as const })),
  ].flatMap(({ item, key, side }) => {
    const a = anchors.get(key)
    if (!a) return []
    const mid = card.y + card.h / 2
    const d = side === 'in' ? curve(a, { x: card.x, y: mid }) : curve({ x: card.x + card.w, y: mid }, a)
    const cls = ['focus-line', item.related ? 'related' : item.live ? 'live' : 'still', a.clipped ? 'clipped' : '', hot === key ? 'hot' : '']
    return [{ key, d, cls: cls.filter(Boolean).join(' '), arrow: item.related ? undefined : `url(#focus-arrow-${item.live ? 'live' : 'still'})` }]
  })

  const column = (side: 'in' | 'out', items: FocusItem[]) => (
    <section className={`focus-side side-${side}`} style={{ width: sideWidth, [side === 'in' ? 'left' : 'right']: inset }}>
      <header className="focus-head">
        {side === 'in' ? 'Waits on' : 'Leads to'} <span>{items.length}</span>
      </header>
      <div className="focus-list" onScroll={measure}>
        {items.length ? (
          items.map((item) => {
            const key = `${side}:${item.id}`
            return (
              <button
                key={key}
                type="button"
                data-key={key}
                data-side={side}
                className={`focus-card st-${item.status}${hot === key ? ' is-hot' : ''}`}
                title={`Focus on ${item.label}`}
                onClick={() => onFocus(item.id)}
                onMouseEnter={() => setHot(key)}
                onMouseLeave={() => setHot(null)}
              >
                <span className="focus-card-meta">
                  <span className="focus-card-tag">{item.tag}</span>
                  <span className="st">{STATUS_LABEL[item.status]}</span>
                </span>
                <span className="label">{item.label}</span>
                <span className="focus-card-where">
                  {item.related && <span className="focus-related">related</span>}
                  {item.where}
                </span>
              </button>
            )
          })
        ) : (
          <p className="focus-empty">{side === 'in' ? 'Nothing to wait on' : 'Nothing waits on this'}</p>
        )}
      </div>
    </section>
  )

  return (
    <div className="focus" ref={root} onAnimationEnd={measure}>
      <svg width={size.w} height={size.h} aria-hidden="true">
        <defs>
          {['live', 'still'].map((kind) => (
            <marker
              key={kind}
              id={`focus-arrow-${kind}`}
              viewBox="0 0 10 10"
              refX="9"
              refY="5"
              markerUnits="userSpaceOnUse"
              markerWidth="11"
              markerHeight="11"
              orient="auto"
            >
              <path d="M0,0 L10,5 L0,10 z" className={`focus-arrow ${kind}`} />
            </marker>
          ))}
        </defs>
        {lines.map((l) => (
          <path key={l.key} d={l.d} className={l.cls} markerEnd={l.arrow} />
        ))}
      </svg>
      {column('in', incoming)}
      {column('out', outgoing)}
      {children && (
        <div
          className="focus-details panel"
          style={{
            left: card.x + card.w / 2,
            top: card.y - DETAILS_GAP,
            width: clamp(card.w, DETAILS_MIN_W, DETAILS_MAX_W),
            maxHeight: Math.max(DETAILS_MIN_H, card.y - DETAILS_GAP - DETAILS_TOP),
          }}
        >
          {children}
        </div>
      )}
      <div className="focus-bar panel">
        <strong title={label}>{label}</strong>
        <button type="button" className="btn" onClick={onExit}>
          Back to canvas <kbd>Esc</kbd>
        </button>
      </div>
    </div>
  )
}
