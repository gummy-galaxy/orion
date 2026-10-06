import { useEffect, useLayoutEffect, useRef, useState, type CSSProperties } from 'react'
import { ViewportPortal, useReactFlow } from '@xyflow/react'
import { STICKERS, stickerKind, type Sticker } from './sticker'

type XY = { x: number; y: number }
export type PlacedSticker = Sticker & { fresh: boolean }

/** Drag below this many screen pixels is a click. */
const DRAG_SLOP = 3
/** Speed kept per millisecond of a toss, so a flick slides a little and stops. */
const FRICTION = 0.991
/** Degrees of lean per canvas pixel per millisecond of sideways speed. */
const LEAN = 14
const MAX_LEAN = 24
const SPRING = 0.14
const DAMPING = 0.72

const reducedMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches

/** Stickers in canvas coordinates, drawn above the cards. */
export function StickerLayer({
  stickers,
  interactive,
  move,
  menu,
}: {
  stickers: PlacedSticker[]
  interactive: boolean
  move: (id: string, at: XY) => void
  menu: (e: React.MouseEvent, id: string) => void
}) {
  return (
    <ViewportPortal>
      {stickers.map((s) => (
        <StickerView key={s.id} sticker={s} interactive={interactive} move={move} menu={menu} />
      ))}
    </ViewportPortal>
  )
}

/**
 * One sticker. Dragging leans it into the motion like something held by its top edge,
 * and letting go mid-flick tosses it, sliding to a stop before it lands.
 */
function StickerView({
  sticker,
  interactive,
  move,
  menu,
}: {
  sticker: PlacedSticker
  interactive: boolean
  move: (id: string, at: XY) => void
  menu: (e: React.MouseEvent, id: string) => void
}) {
  const rf = useReactFlow()
  const [live, setLive] = useState<{ dx: number; dy: number; lean: number; held: boolean } | null>(null)
  const sim = useRef({ held: false, moved: false, startX: 0, startY: 0, dx: 0, dy: 0, vx: 0, vy: 0, lean: 0, spin: 0, at: 0, movedAt: 0, frame: 0 })

  useEffect(() => () => cancelAnimationFrame(sim.current.frame), [])

  const step = (now: number) => {
    const s = sim.current
    const dt = Math.min(32, now - s.at)
    s.at = now
    if (!s.held) {
      s.dx += s.vx * dt
      s.dy += s.vy * dt
      const keep = Math.pow(FRICTION, dt)
      s.vx *= keep
      s.vy *= keep
    }
    const target = s.held ? Math.max(-MAX_LEAN, Math.min(MAX_LEAN, s.vx * LEAN)) : 0
    s.spin = (s.spin + (target - s.lean) * SPRING) * DAMPING
    s.lean += s.spin
    const resting = !s.held && Math.hypot(s.vx, s.vy) < 0.004 && Math.abs(s.lean) < 0.2 && Math.abs(s.spin) < 0.05
    if (resting) {
      s.frame = 0
      move(sticker.id, { x: sticker.x + s.dx, y: sticker.y + s.dy })
      setLive(null)
      return
    }
    setLive({ dx: s.dx, dy: s.dy, lean: s.lean, held: s.held })
    s.frame = requestAnimationFrame(step)
  }

  const onPointerDown = (e: React.PointerEvent) => {
    if (e.button !== 0 || !interactive) return
    e.stopPropagation()
    e.currentTarget.setPointerCapture(e.pointerId)
    const s = sim.current
    cancelAnimationFrame(s.frame)
    s.frame = 0
    Object.assign(s, { held: true, moved: false, startX: e.clientX - s.dx * rf.getZoom(), startY: e.clientY - s.dy * rf.getZoom(), vx: 0, vy: 0 })
    s.at = performance.now()
    s.movedAt = s.at
  }

  const onPointerMove = (e: React.PointerEvent) => {
    const s = sim.current
    if (!s.held) return
    const zoom = rf.getZoom()
    const dx = (e.clientX - s.startX) / zoom
    const dy = (e.clientY - s.startY) / zoom
    if (!s.moved && Math.hypot(dx * zoom, dy * zoom) < DRAG_SLOP) return
    const now = performance.now()
    const dt = Math.max(1, now - s.movedAt)
    // Smoothed, so the toss follows the last few moves rather than the final twitch.
    s.vx = s.vx * 0.6 + ((dx - s.dx) / dt) * 0.4
    s.vy = s.vy * 0.6 + ((dy - s.dy) / dt) * 0.4
    s.dx = dx
    s.dy = dy
    s.movedAt = now
    if (!s.moved) {
      s.moved = true
      s.at = now
      if (reducedMotion()) setLive({ dx, dy, lean: 0, held: true })
      else s.frame = requestAnimationFrame(step)
    } else if (reducedMotion()) setLive({ dx, dy, lean: 0, held: true })
  }

  const onPointerUp = (e: React.PointerEvent) => {
    const s = sim.current
    if (!s.held) return
    e.currentTarget.releasePointerCapture(e.pointerId)
    s.held = false
    if (!s.moved) return
    // A pause before letting go drops it in place instead of tossing it.
    if (performance.now() - s.movedAt > 60 || reducedMotion()) {
      s.vx = 0
      s.vy = 0
    }
    if (reducedMotion()) {
      move(sticker.id, { x: sticker.x + s.dx, y: sticker.y + s.dy })
      setLive(null)
    }
  }

  useEffect(() => {
    // Landing commits the new spot; start the next drag from there.
    if (!live) Object.assign(sim.current, { dx: 0, dy: 0, lean: 0, spin: 0 })
  }, [live, sticker.x, sticker.y])

  const kind = stickerKind(sticker.kind)
  return (
    <div
      className={`sticker nopan${sticker.fresh ? ' is-fresh' : ''}${live ? ' is-moving' : ''}${live?.held ? ' is-held' : ''}${interactive ? ' is-interactive' : ''}`}
      style={
        {
          transform: `translate(${sticker.x + (live?.dx ?? 0)}px, ${sticker.y + (live?.dy ?? 0)}px)`,
          '--tilt': `${sticker.tilt + (live?.lean ?? 0)}deg`,
        } as CSSProperties
      }
      title={kind.label}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerCancel={onPointerUp}
      onContextMenu={(e) => {
        e.stopPropagation()
        menu(e, sticker.id)
      }}
    >
      <span className="sticker-art">{kind.emoji}</span>
    </div>
  )
}

const WHEEL_RADIUS = 72
const WHEEL_EDGE = 120
const HUB = 30

/**
 * Picks a sticker. Opened by holding S, it follows FigJam: point at one and let go.
 * A quick tap leaves it open for clicking, as does opening it from the toolbar.
 */
export function StickerWheel({
  at,
  held,
  current,
  pick,
  close,
}: {
  at: XY
  held: boolean
  current: string
  pick: (id: string) => void
  close: () => void
}) {
  const [hover, setHover] = useState<number | null>(null)
  const center = {
    x: Math.max(WHEEL_EDGE, Math.min(window.innerWidth - WHEEL_EDGE, at.x)),
    y: Math.max(WHEEL_EDGE, Math.min(window.innerHeight - WHEEL_EDGE, at.y)),
  }
  const latest = useRef({ hover, held, pick, close })
  useLayoutEffect(() => {
    latest.current = { hover, held, pick, close }
  })

  useEffect(() => {
    const opened = performance.now()
    const down = (e: KeyboardEvent) => {
      const { hover, pick, close } = latest.current
      const digit = Number(e.key)
      if (e.key === 'Escape') close()
      else if (Number.isInteger(digit) && digit >= 1 && digit <= STICKERS.length) pick(STICKERS[digit - 1].id)
      else if (e.key === 'Enter' && hover !== null) pick(STICKERS[hover].id)
      else if (e.key.toLowerCase() !== 's') return
      e.preventDefault()
      e.stopImmediatePropagation()
    }
    const up = (e: KeyboardEvent) => {
      const { hover, held, pick, close } = latest.current
      if (!held || e.key.toLowerCase() !== 's') return
      if (hover !== null) pick(STICKERS[hover].id)
      else if (performance.now() - opened > 350) close()
    }
    window.addEventListener('keydown', down, { capture: true })
    window.addEventListener('keyup', up)
    return () => {
      window.removeEventListener('keydown', down, { capture: true })
      window.removeEventListener('keyup', up)
    }
  }, [])

  const track = (e: React.PointerEvent) => {
    const dx = e.clientX - center.x
    const dy = e.clientY - center.y
    const d = Math.hypot(dx, dy)
    if (d < HUB || d > WHEEL_EDGE * 1.6) return setHover(null)
    const turn = (Math.atan2(dx, -dy) / (2 * Math.PI) + 1) % 1
    setHover(Math.round(turn * STICKERS.length) % STICKERS.length)
  }

  const shown = hover !== null ? STICKERS[hover] : stickerKind(current)
  return (
    <div
      className="wheel-backdrop"
      onPointerMove={track}
      onPointerDown={(e) => e.target === e.currentTarget && close()}
      onContextMenu={(e) => {
        e.preventDefault()
        close()
      }}
    >
      <div className="wheel" style={{ left: center.x, top: center.y }} role="menu" aria-label="Stickers">
        {STICKERS.map((s, i) => {
          const angle = (i / STICKERS.length) * 2 * Math.PI
          return (
            <button
              key={s.id}
              type="button"
              role="menuitem"
              className={`wheel-item${hover === i ? ' hover' : ''}${current === s.id ? ' current' : ''}`}
              style={{ '--x': `${Math.sin(angle) * WHEEL_RADIUS}px`, '--y': `${-Math.cos(angle) * WHEEL_RADIUS}px`, '--i': i } as CSSProperties}
              title={`${s.label} (${i + 1})`}
              onClick={() => pick(s.id)}
            >
              {s.emoji}
            </button>
          )
        })}
        <span className="wheel-hub">{shown.label}</span>
      </div>
    </div>
  )
}
