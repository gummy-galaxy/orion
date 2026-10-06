import { useEffect, useLayoutEffect, useRef, useState, type CSSProperties } from 'react'
import { ViewportPortal, useReactFlow, type ReactFlowInstance } from '@xyflow/react'
import { STICKERS, stickerKind, type Sticker } from './sticker'

type XY = { x: number; y: number }
export type PlacedSticker = Sticker & { fresh: boolean }
/** A visible group's frame in canvas coordinates. `parent` is the nearest visible group around it. */
export type StickerBounds = { id: string; x0: number; y0: number; x1: number; y1: number; parent: string | null; depth: number }
export type StickerMove = { id: string; x: number; y: number }

/** Drag below this many screen pixels is a click. */
const DRAG_SLOP = 3
const RADIUS = 20
const STEP_MS = 4
const MAX_FRAME_MS = 48
/** Canvas pixels per millisecond. Keeps a hard throw from tunneling through anything. */
const MAX_SPEED = 3
/** Speed kept per millisecond, low like an air hockey table. */
const FRICTION = 0.9955
const BOUNCE = 0.85
const WALL_BOUNCE = 0.7
/** A held sticker chases the cursor on a stiff spring, damped so it barely overshoots. */
const CHASE = 0.04
const CHASE_DAMPING = 2 * 0.8 * Math.sqrt(CHASE)
/** How far past a group's edge the cursor goes, in screen pixels, before the sticker pops through. */
const POP_DISTANCE = 90
/** How much of the cursor's pull shows as the sticker straining through the edge. */
const STRAIN = 0.3
/** Speed given to stickers a fresh stamp lands on. */
const STAMP_KNOCK = 0.8
/** Degrees of lean per canvas pixel per millisecond of sideways speed. */
const LEAN = 14
const MAX_LEAN = 24
const SPRING = 0.14
const DAMPING = 0.72
const HIT_WOBBLE = 18
const REST_SPEED = 0.004

const reducedMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches
const clamp = (v: number, lo: number, hi: number) => (lo > hi ? (lo + hi) / 2 : Math.max(lo, Math.min(hi, v)))

type Body = {
  id: string
  x: number
  y: number
  vx: number
  vy: number
  lean: number
  spin: number
  /** The innermost group it's inside, which it can only leave by being dragged out. */
  home: string | null
  fromX: number
  fromY: number
  resting: boolean
}

type Hold = { id: string; pointerId: number; startX: number; startY: number; offset: XY; at: XY; active: boolean }

function homeAt(p: XY, bounds: StickerBounds[]) {
  let best: StickerBounds | null = null
  for (const b of bounds) if (p.x >= b.x0 && p.x <= b.x1 && p.y >= b.y0 && p.y <= b.y1 && (!best || b.depth > best.depth)) best = b
  return best?.id ?? null
}

/** Groups directly inside a sticker's home, which it bounces off from outside. */
const obstacles = (home: string | null, bounds: Map<string, StickerBounds>) => [...bounds.values()].filter((o) => o.parent === home && o.id !== home)

/**
 * Where a held sticker goes for a cursor at `p`. It stays inside its home and outside the
 * groups in it, straining through whichever edge it's pulled against, until the cursor gets
 * far enough past the edge to pop it through.
 */
function chaseTarget(body: Body, p: XY, bounds: Map<string, StickerBounds>, pop: number): XY {
  const home = body.home ? bounds.get(body.home) : undefined
  if (home) {
    const out = Math.hypot(Math.max(home.x0 - p.x, 0, p.x - home.x1), Math.max(home.y0 - p.y, 0, p.y - home.y1))
    if (out > pop) {
      body.home = home.parent
      return chaseTarget(body, p, bounds, pop)
    }
    const inside = { x: clamp(p.x, home.x0 + RADIUS, home.x1 - RADIUS), y: clamp(p.y, home.y0 + RADIUS, home.y1 - RADIUS) }
    const pull = Math.hypot(p.x - inside.x, p.y - inside.y)
    if (out > 0 && pull > 0) {
      const strain = Math.min(RADIUS, out * STRAIN) / pull
      return { x: inside.x + (p.x - inside.x) * strain, y: inside.y + (p.y - inside.y) * strain }
    }
    p = inside
  }
  for (const o of obstacles(body.home, bounds)) {
    if (p.x < o.x0 - RADIUS || p.x > o.x1 + RADIUS || p.y < o.y0 - RADIUS || p.y > o.y1 + RADIUS) continue
    // The side the sticker is on is the edge it presses against.
    const gaps = [o.x0 - body.x, body.x - o.x1, o.y0 - body.y, body.y - o.y1]
    const side = gaps.indexOf(Math.max(...gaps))
    const depth = [p.x - o.x0, o.x1 - p.x, p.y - o.y0, o.y1 - p.y][side]
    if (depth > pop) {
      body.home = o.id
      return chaseTarget(body, p, bounds, pop)
    }
    const strain = Math.min(RADIUS, (depth + RADIUS) * STRAIN)
    if (side === 0) return { x: o.x0 - RADIUS + strain, y: p.y }
    if (side === 1) return { x: o.x1 + RADIUS - strain, y: p.y }
    if (side === 2) return { x: p.x, y: o.y0 - RADIUS + strain }
    return { x: p.x, y: o.y1 + RADIUS - strain }
  }
  return p
}

function bounceOffWalls(b: Body, bounds: Map<string, StickerBounds>) {
  const home = b.home ? bounds.get(b.home) : undefined
  if (home) {
    const wall = (normalX: number, normalY: number) => {
      const vn = b.vx * normalX + b.vy * normalY
      if (vn >= 0) return
      b.vx -= (1 + WALL_BOUNCE) * vn * normalX
      b.vy -= (1 + WALL_BOUNCE) * vn * normalY
      b.spin += (normalX ? b.vy : -b.vx) * HIT_WOBBLE * 0.5
    }
    const x = clamp(b.x, home.x0 + RADIUS, home.x1 - RADIUS)
    const y = clamp(b.y, home.y0 + RADIUS, home.y1 - RADIUS)
    if (x !== b.x) wall(Math.sign(x - b.x), 0)
    if (y !== b.y) wall(0, Math.sign(y - b.y))
    b.x = x
    b.y = y
  }
  for (const o of obstacles(b.home, bounds)) {
    const dx = b.x - clamp(b.x, o.x0, o.x1)
    const dy = b.y - clamp(b.y, o.y0, o.y1)
    const d = Math.hypot(dx, dy)
    if (d >= RADIUS) continue
    let nx: number
    let ny: number
    let depth: number
    if (d > 0) {
      nx = dx / d
      ny = dy / d
      depth = RADIUS - d
    } else {
      const sides = [b.x - o.x0, o.x1 - b.x, b.y - o.y0, o.y1 - b.y]
      const side = sides.indexOf(Math.min(...sides))
      ;[nx, ny] = [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ][side]
      depth = sides[side] + RADIUS
    }
    b.x += nx * depth
    b.y += ny * depth
    const vn = b.vx * nx + b.vy * ny
    if (vn < 0) {
      b.vx -= (1 + WALL_BOUNCE) * vn * nx
      b.vy -= (1 + WALL_BOUNCE) * vn * ny
    }
  }
}

/** Two stickers bump like pucks. A held one is the mallet: it pushes and never gets pushed. */
function collide(a: Body, b: Body, held: Body | undefined) {
  if (a.home !== b.home || (a.resting && b.resting)) return
  const dx = b.x - a.x
  const dy = b.y - a.y
  const d = Math.hypot(dx, dy)
  if (d >= RADIUS * 2) return
  const [nx, ny] = d > 1e-6 ? [dx / d, dy / d] : [1, 0]
  const overlap = RADIUS * 2 - d
  const rvx = b.vx - a.vx
  const rvy = b.vy - a.vy
  const vn = rvx * nx + rvy * ny
  if (a === held) {
    b.x += nx * overlap
    b.y += ny * overlap
    if (vn < 0) {
      b.vx -= (1 + BOUNCE) * vn * nx
      b.vy -= (1 + BOUNCE) * vn * ny
    }
  } else if (b === held) {
    a.x -= nx * overlap
    a.y -= ny * overlap
    if (vn < 0) {
      a.vx += (1 + BOUNCE) * vn * nx
      a.vy += (1 + BOUNCE) * vn * ny
    }
  } else {
    a.x -= (nx * overlap) / 2
    a.y -= (ny * overlap) / 2
    b.x += (nx * overlap) / 2
    b.y += (ny * overlap) / 2
    if (vn < 0) {
      const j = ((1 + BOUNCE) * vn) / 2
      a.vx += j * nx
      a.vy += j * ny
      b.vx -= j * nx
      b.vy -= j * ny
    }
  }
  if (vn < 0) {
    const vt = rvy * nx - rvx * ny
    a.spin -= vt * HIT_WOBBLE
    b.spin += vt * HIT_WOBBLE
  }
  a.resting = false
  b.resting = false
}

/** Every sticker as a puck on one table. It runs only while something is moving. */
class StickerWorld {
  bodies = new Map<string, Body>()
  hold: Hold | null = null
  private frame = 0
  private at = 0
  private stickers: PlacedSticker[] = []
  private list: StickerBounds[] = []
  private bounds = new Map<string, StickerBounds>()
  private settle: (moves: StickerMove[]) => void = () => {}
  private rf: ReactFlowInstance | null = null
  private draw: () => void

  constructor(draw: () => void) {
    this.draw = draw
  }

  update(stickers: PlacedSticker[], bounds: StickerBounds[], settle: (moves: StickerMove[]) => void, rf: ReactFlowInstance) {
    this.stickers = stickers
    this.list = bounds
    this.bounds = new Map(bounds.map((b) => [b.id, b]))
    this.settle = settle
    this.rf = rf
    // Asleep, the stickers' own positions have caught up with where the bodies landed.
    if (!this.frame && !this.hold) this.bodies.clear()
  }

  stop() {
    cancelAnimationFrame(this.frame)
    this.frame = 0
  }

  position(s: PlacedSticker) {
    const b = this.bodies.get(s.id)
    return b ? { x: b.x, y: b.y, lean: b.lean } : { x: s.x, y: s.y, lean: 0 }
  }

  private newBody(s: PlacedSticker): Body {
    return { id: s.id, x: s.x, y: s.y, vx: 0, vy: 0, lean: 0, spin: 0, home: homeAt(s, this.list), fromX: s.x, fromY: s.y, resting: true }
  }

  private wake() {
    if (this.frame) return
    if (!this.bodies.size) for (const s of this.stickers) this.bodies.set(s.id, this.newBody(s))
    this.at = performance.now()
    this.frame = requestAnimationFrame(this.step)
  }

  /** A fresh stamp knocks aside whatever it lands on. */
  stamped(id: string) {
    if (reducedMotion()) return
    this.wake()
    const s = this.bodies.get(id)
    if (!s) return
    for (const b of this.bodies.values()) {
      const d = Math.hypot(b.x - s.x, b.y - s.y)
      if (b === s || b.home !== s.home || d >= RADIUS * 2) continue
      const angle = Math.random() * 2 * Math.PI
      const [nx, ny] = d > 1e-6 ? [(b.x - s.x) / d, (b.y - s.y) / d] : [Math.cos(angle), Math.sin(angle)]
      b.vx += nx * STAMP_KNOCK
      b.vy += ny * STAMP_KNOCK
      b.resting = false
    }
  }

  private flow(e: { clientX: number; clientY: number }) {
    return this.rf ? this.rf.screenToFlowPosition({ x: e.clientX, y: e.clientY }) : { x: e.clientX, y: e.clientY }
  }

  grab(id: string, e: React.PointerEvent) {
    const at = this.flow(e)
    const s = this.bodies.get(id) ?? this.stickers.find((x) => x.id === id)
    if (!s) return
    this.hold = {
      id,
      pointerId: e.pointerId,
      startX: e.clientX,
      startY: e.clientY,
      offset: { x: s.x - at.x, y: s.y - at.y },
      at: { x: s.x, y: s.y },
      active: false,
    }
  }

  drag(e: React.PointerEvent) {
    const h = this.hold
    if (!h || h.pointerId !== e.pointerId) return
    if (!h.active && Math.hypot(e.clientX - h.startX, e.clientY - h.startY) < DRAG_SLOP) return
    const at = this.flow(e)
    h.at = { x: at.x + h.offset.x, y: at.y + h.offset.y }
    if (h.active) return
    h.active = true
    this.wake()
    const b = this.bodies.get(h.id)
    if (b) b.resting = false
  }

  release(e: React.PointerEvent) {
    if (this.hold?.pointerId !== e.pointerId) return
    this.hold = null
  }

  private step = (now: number) => {
    const elapsed = Math.min(MAX_FRAME_MS, now - this.at)
    this.at = now
    const still = reducedMotion()
    const ids = new Set(this.stickers.map((s) => s.id))
    for (const id of this.bodies.keys()) if (!ids.has(id)) this.bodies.delete(id)
    for (const s of this.stickers) {
      const b = this.bodies.get(s.id)
      if (!b) this.bodies.set(s.id, this.newBody(s))
      // Untouched stickers keep riding along with the card under them.
      else if (b.resting && b.x === b.fromX && b.y === b.fromY) {
        b.x = b.fromX = s.x
        b.y = b.fromY = s.y
      }
    }
    const all = [...this.bodies.values()]
    const held = this.hold?.active ? this.bodies.get(this.hold.id) : undefined
    const pop = POP_DISTANCE / (this.rf?.getZoom() ?? 1)
    const steps = Math.max(1, Math.ceil(elapsed / STEP_MS))
    const h = elapsed / steps
    const keep = Math.pow(FRICTION, h)
    for (let i = 0; i < steps; i++) {
      if (held && this.hold) {
        const t = chaseTarget(held, this.hold.at, this.bounds, pop)
        if (still) Object.assign(held, { x: t.x, y: t.y, vx: 0, vy: 0 })
        else {
          held.vx += (CHASE * (t.x - held.x) - CHASE_DAMPING * held.vx) * h
          held.vy += (CHASE * (t.y - held.y) - CHASE_DAMPING * held.vy) * h
          held.x += held.vx * h
          held.y += held.vy * h
        }
      }
      if (still) break
      for (const b of all) {
        if (b === held || b.resting) continue
        const speed = Math.hypot(b.vx, b.vy)
        if (speed > MAX_SPEED) {
          b.vx *= MAX_SPEED / speed
          b.vy *= MAX_SPEED / speed
        }
        b.x += b.vx * h
        b.y += b.vy * h
        b.vx *= keep
        b.vy *= keep
        bounceOffWalls(b, this.bounds)
      }
      for (let a = 0; a < all.length; a++) for (let c = a + 1; c < all.length; c++) collide(all[a], all[c], held)
    }
    let awake = !!this.hold
    for (const b of all) {
      const target = b === held && !still ? clamp(b.vx * LEAN, -MAX_LEAN, MAX_LEAN) : 0
      b.spin = (b.spin + (target - b.lean) * SPRING) * DAMPING
      b.lean += b.spin
      if (b === held) continue
      if (!b.resting && Math.hypot(b.vx, b.vy) < REST_SPEED && Math.abs(b.lean) < 0.2 && Math.abs(b.spin) < 0.05) {
        b.vx = 0
        b.vy = 0
        b.lean = 0
        b.resting = true
      }
      if (!b.resting || Math.abs(b.lean) > 0.2) awake = true
    }
    this.draw()
    if (awake) {
      this.frame = requestAnimationFrame(this.step)
      return
    }
    this.frame = 0
    const moves = all.filter((b) => Math.hypot(b.x - b.fromX, b.y - b.fromY) > 0.5).map((b) => ({ id: b.id, x: b.x, y: b.y }))
    if (moves.length) this.settle(moves)
    else this.bodies.clear()
  }
}

/** Stickers in canvas coordinates, drawn above the cards. */
export function StickerLayer({
  stickers,
  bounds,
  interactive,
  settle,
  menu,
}: {
  stickers: PlacedSticker[]
  bounds: StickerBounds[]
  interactive: boolean
  settle: (moves: StickerMove[]) => void
  menu: (e: React.MouseEvent, id: string) => void
}) {
  const rf = useReactFlow()
  const [, redraw] = useState(0)
  const [world] = useState(() => new StickerWorld(() => redraw((n) => n + 1)))
  useLayoutEffect(() => world.update(stickers, bounds, settle, rf))
  useEffect(() => () => world.stop(), [world])

  const seen = useRef<Set<string> | null>(null)
  useEffect(() => {
    const before = seen.current
    seen.current = new Set(stickers.map((s) => s.id))
    if (before) for (const s of stickers) if (s.fresh && !before.has(s.id)) world.stamped(s.id)
  }, [stickers, world])

  return (
    <ViewportPortal>
      {stickers.map((s) => {
        const at = world.position(s)
        const held = world.hold?.active && world.hold.id === s.id
        const kind = stickerKind(s.kind)
        return (
          <div
            key={s.id}
            className={`sticker nopan${s.fresh ? ' is-fresh' : ''}${held ? ' is-held' : ''}${interactive ? ' is-interactive' : ''}`}
            style={{ transform: `translate(${at.x}px, ${at.y}px)`, '--tilt': `${s.tilt + at.lean}deg` } as CSSProperties}
            title={kind.label}
            onPointerDown={(e) => {
              if (e.button !== 0 || !interactive) return
              e.stopPropagation()
              e.currentTarget.setPointerCapture(e.pointerId)
              world.grab(s.id, e)
            }}
            onPointerMove={(e) => world.drag(e)}
            onPointerUp={(e) => world.release(e)}
            onPointerCancel={(e) => world.release(e)}
            onContextMenu={(e) => {
              e.stopPropagation()
              menu(e, s.id)
            }}
          >
            <span className="sticker-art">{kind.emoji}</span>
          </div>
        )
      })}
    </ViewportPortal>
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
