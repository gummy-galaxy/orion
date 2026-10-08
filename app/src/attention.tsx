/**
 * Lines from the cursor to everything that needs you while ⌥ is held. Work off
 * screen gets a chip at the edge, in the direction of the work, that jumps to it.
 */

export type Point = { x: number; y: number }
export type Rect = { x: number; y: number; width: number; height: number }
/** `id` is the card or folded group drawn; `jump` is the first piece of work inside it. */
export type AttentionTarget = { id: string; jump: string; label: string; count: number; rect: Rect }

const EDGE_INSET = 28
const CHIP_MAX_WIDTH = 180

const clamp = (value: number, minimum: number, maximum: number) => Math.max(minimum, Math.min(maximum, value))

function nearest(point: Point, rectangle: Rect): Point {
  return { x: clamp(point.x, rectangle.x, rectangle.x + rectangle.width), y: clamp(point.y, rectangle.y, rectangle.y + rectangle.height) }
}

/** Where the line from `from` toward `to` leaves the inset frame. */
function exitPoint(from: Point, to: Point, width: number, height: number): Point {
  const deltaX = to.x - from.x
  const deltaY = to.y - from.y
  let target = 1
  if (deltaX > 0) target = Math.min(target, (width - EDGE_INSET - from.x) / deltaX)
  if (deltaX < 0) target = Math.min(target, (EDGE_INSET - from.x) / deltaX)
  if (deltaY > 0) target = Math.min(target, (height - EDGE_INSET - from.y) / deltaY)
  if (deltaY < 0) target = Math.min(target, (EDGE_INSET - from.y) / deltaY)
  target = Math.max(0, target)
  return { x: from.x + deltaX * target, y: from.y + deltaY * target }
}

export function AttentionOverlay({
  targets,
  count,
  elsewhere,
  cursor,
  width,
  height,
  onJump,
}: {
  targets: AttentionTarget[]
  count: number
  elsewhere: number
  cursor: Point
  width: number
  height: number
  onJump: (id: string) => void
}) {
  const lines = targets.map((target) => {
    const rectangle = target.rect
    const onScreen = rectangle.x + rectangle.width > 0 && rectangle.y + rectangle.height > 0 && rectangle.x < width && rectangle.y < height
    if (onScreen) return { t: target, end: nearest(cursor, rectangle), chip: null }
    const end = exitPoint(cursor, { x: rectangle.x + rectangle.width / 2, y: rectangle.y + rectangle.height / 2 }, width, height)
    return { t: target, end, chip: end }
  })
  return (
    <div className="attention" aria-hidden="true">
      <svg width={width} height={height}>
        {lines.map(({ t: target, end }) => (
          <g key={target.id} className="attn-line">
            <line x1={cursor.x} y1={cursor.y} x2={end.x} y2={end.y} />
            <circle cx={end.x} cy={end.y} r={3.5} />
          </g>
        ))}
        <circle className="attn-origin" cx={cursor.x} cy={cursor.y} r={4} />
      </svg>
      {lines.map(
        ({ t: target, chip }) =>
          chip && (
            <button
              key={target.id}
              type="button"
              className="attn-chip"
              style={{
                left: clamp(chip.x, 8, width - 8),
                top: clamp(chip.y, 20, height - 20),
                maxWidth: CHIP_MAX_WIDTH,
                // Chips grow away from the edge they sit on.
                transform: `translate(${chip.x > width / 2 ? '-100%' : '0'}, -50%)`,
              }}
              onPointerDown={(event) => {
                event.stopPropagation()
                onJump(target.jump)
              }}
            >
              {target.count > 1 ? `${target.count} · ` : ''}
              {target.label}
            </button>
          ),
      )}
      <div className="attn-tally" style={{ left: clamp(cursor.x + 14, 8, width - 220), top: clamp(cursor.y + 16, 8, height - 30) }}>
        <strong>{count}</strong> your move
        {elsewhere > 0 && <> · {elsewhere} outside this group</>}
      </div>
    </div>
  )
}
