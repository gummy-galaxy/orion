/**
 * Focus on one card: the canvas zooms onto it, and everything it waits on and
 * leads to lines up in scrolling columns on either side, wired into its edges.
 */
import { useCallback, useLayoutEffect, useRef, useState, type ReactNode } from 'react'
import type { Rect } from './AttentionOverlay'
import type { Flow } from '../derive'
import { STATUS_LABEL, type ViewStatus } from '../model'

/** Lines from cards scrolled out of a column stop this far inside its edge. */
const CLIP_INSET = 6
const DETAILS_GAP = 24
/** Room kept clear at the top for the bar with the way back. */
const DETAILS_TOP = 64
const DETAILS_MIN_WIDTH = 300
const DETAILS_MAX_WIDTH = 440
const DETAILS_MIN_HEIGHT = 160

export type FocusItem = {
  id: string
  label: string
  tag: string
  status: ViewStatus
  where: string
  related: boolean
  /** How the link between this card and the focused one reads. */
  flow: Flow
}

type Anchor = { x: number; y: number; clipped: boolean }

const clamp = (value: number, minimum: number, maximum: number) => Math.max(minimum, Math.min(maximum, value))

function curve(start: { x: number; y: number }, end: { x: number; y: number }) {
  const deltaX = Math.max(40, Math.abs(end.x - start.x) / 2)
  return `M${start.x},${start.y} C${start.x + deltaX},${start.y} ${end.x - deltaX},${end.y} ${end.x},${end.y}`
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
  const [size, setSize] = useState({ width: 0, height: 0 })
  const [anchors, setAnchors] = useState<Map<string, Anchor>>(() => new Map())
  const [hot, setHot] = useState<string | null>(null)

  const measure = useCallback(() => {
    const element = root.current
    if (!element) return
    const box = element.getBoundingClientRect()
    const next = new Map<string, Anchor>()
    for (const list of element.querySelectorAll<HTMLElement>('.focus-list')) {
      const bounds = list.getBoundingClientRect()
      for (const item of list.querySelectorAll<HTMLElement>('[data-key]')) {
        const rectangle = item.getBoundingClientRect()
        const middle = rectangle.top + rectangle.height / 2
        const y = clamp(middle, bounds.top + CLIP_INSET, bounds.bottom - CLIP_INSET)
        next.set(item.dataset.key!, {
          x: (item.dataset.side === 'in' ? rectangle.right : rectangle.left) - box.left,
          y: y - box.top,
          clipped: y !== middle,
        })
      }
    }
    setSize({ width: box.width, height: box.height })
    setAnchors(next)
  }, [])

  useLayoutEffect(measure, [measure, incoming, outgoing])
  useLayoutEffect(() => {
    const element = root.current
    if (!element) return
    const observer = new ResizeObserver(measure)
    observer.observe(element)
    return () => observer.disconnect()
  }, [measure])

  const lines = [
    ...incoming.map((item) => ({ item, key: `in:${item.id}`, side: 'in' as const })),
    ...outgoing.map((item) => ({ item, key: `out:${item.id}`, side: 'out' as const })),
  ].flatMap(({ item, key, side }) => {
    const start = anchors.get(key)
    if (!start) return []
    const middle = card.y + card.height / 2
    const pathData = side === 'in' ? curve(start, { x: card.x, y: middle }) : curve({ x: card.x + card.width, y: middle }, start)
    const classNames = ['focus-line', item.related ? 'related' : item.flow, start.clipped ? 'clipped' : '', hot === key ? 'hot' : '']
    return [{ key, d: pathData, cls: classNames.filter(Boolean).join(' '), arrow: item.related ? undefined : `url(#focus-arrow-${item.flow})` }]
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
      <svg width={size.width} height={size.height} aria-hidden="true">
        <defs>
          {['live', 'held'].map((kind) => (
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
        {lines.map((line) => (
          <path key={line.key} d={line.d} className={line.cls} markerEnd={line.arrow} />
        ))}
      </svg>
      {column('in', incoming)}
      {column('out', outgoing)}
      {children && (
        <div
          className="focus-details panel"
          style={{
            left: card.x + card.width / 2,
            top: card.y - DETAILS_GAP,
            width: clamp(card.width, DETAILS_MIN_WIDTH, DETAILS_MAX_WIDTH),
            maxHeight: Math.max(DETAILS_MIN_HEIGHT, card.y - DETAILS_GAP - DETAILS_TOP),
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
