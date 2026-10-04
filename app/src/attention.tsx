import type { AttentionTier } from './derive'

/**
 * Lines from the cursor to everything that needs you while ⌘ is held. Work off
 * screen gets a chip at the edge, in the direction of the work, that jumps to it.
 */

export type Point = { x: number; y: number }
export type Rect = { x: number; y: number; w: number; h: number }
/** `id` is the card or folded group drawn; `jump` is the first piece of work inside it. */
export type AttentionTarget = { id: string; jump: string; label: string; count: number; tier: AttentionTier; rect: Rect }

const EDGE_INSET = 28
const CHIP_MAX = 180

const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v))

function nearest(p: Point, r: Rect): Point {
  return { x: clamp(p.x, r.x, r.x + r.w), y: clamp(p.y, r.y, r.y + r.h) }
}

/** Where the line from `from` toward `to` leaves the inset frame. */
function exitPoint(from: Point, to: Point, w: number, h: number): Point {
  const dx = to.x - from.x
  const dy = to.y - from.y
  let t = 1
  if (dx > 0) t = Math.min(t, (w - EDGE_INSET - from.x) / dx)
  if (dx < 0) t = Math.min(t, (EDGE_INSET - from.x) / dx)
  if (dy > 0) t = Math.min(t, (h - EDGE_INSET - from.y) / dy)
  if (dy < 0) t = Math.min(t, (EDGE_INSET - from.y) / dy)
  t = Math.max(0, t)
  return { x: from.x + dx * t, y: from.y + dy * t }
}

export function AttentionOverlay({
  targets,
  tally,
  elsewhere,
  cursor,
  width,
  height,
  onJump,
}: {
  targets: AttentionTarget[]
  tally: Record<AttentionTier, number>
  elsewhere: number
  cursor: Point
  width: number
  height: number
  onJump: (id: string) => void
}) {
  const lines = targets.map((t) => {
    const r = t.rect
    const onScreen = r.x + r.w > 0 && r.y + r.h > 0 && r.x < width && r.y < height
    if (onScreen) return { t, end: nearest(cursor, r), chip: null }
    const end = exitPoint(cursor, { x: r.x + r.w / 2, y: r.y + r.h / 2 }, width, height)
    return { t, end, chip: end }
  })
  return (
    <div className="attention" aria-hidden="true">
      <svg width={width} height={height}>
        {lines.map(({ t, end }) => (
          <g key={t.id} className={`attn-line attn-${t.tier}`}>
            <line x1={cursor.x} y1={cursor.y} x2={end.x} y2={end.y} />
            <circle cx={end.x} cy={end.y} r={3.5} />
          </g>
        ))}
        <circle className="attn-origin" cx={cursor.x} cy={cursor.y} r={4} />
      </svg>
      {lines.map(
        ({ t, chip }) =>
          chip && (
            <button
              key={t.id}
              type="button"
              className={`attn-chip attn-${t.tier}`}
              style={{
                left: clamp(chip.x, 8, width - 8),
                top: clamp(chip.y, 20, height - 20),
                maxWidth: CHIP_MAX,
                // Chips grow away from the edge they sit on.
                transform: `translate(${chip.x > width / 2 ? '-100%' : '0'}, -50%)`,
              }}
              onPointerDown={(e) => {
                e.stopPropagation()
                onJump(t.jump)
              }}
            >
              {t.count > 1 ? `${t.count} · ` : ''}
              {t.label}
            </button>
          ),
      )}
      <div className="attn-tally" style={{ left: clamp(cursor.x + 14, 8, width - 220), top: clamp(cursor.y + 16, 8, height - 30) }}>
        <span className="attn-mine">{tally.mine} your move</span> · <span className="attn-start">{tally.start} ready to start</span>
        {elsewhere > 0 && <> · {elsewhere} outside this group</>}
      </div>
    </div>
  )
}
