import { useEffect, useLayoutEffect, useRef, useState, type CSSProperties } from 'react'
import { ViewportPortal, useReactFlow, type ReactFlowInstance } from '@xyflow/react'
import { WHEEL_SLOTS, firstEmoji, type Loadout, type Sticker } from './sticker'

type StickerPoint = { x: number; y: number }
export type PlacedSticker = Sticker & { fresh: boolean }
/** A visible group's frame in canvas coordinates. `parent` is the nearest visible group around it. */
export type StickerBounds = { id: string; x0: number; y0: number; x1: number; y1: number; parent: string | null; depth: number }
export type StickerMove = { id: string; x: number; y: number }

/** Drag below this many screen pixels is a click. */
const DRAG_SLOP = 3
const RADIUS = 20
const STEP_MILLISECONDS = 4
const MAX_FRAME_MILLISECONDS = 48
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
const clamp = (value: number, minimum: number, maximum: number) =>
  minimum > maximum ? (minimum + maximum) / 2 : Math.max(minimum, Math.min(maximum, value))

type Body = {
  id: string
  x: number
  y: number
  velocityX: number
  velocityY: number
  lean: number
  spin: number
  /** The innermost group it's inside, which it can only leave by being dragged out. */
  home: string | null
  fromX: number
  fromY: number
  resting: boolean
}

type Hold = { id: string; pointerId: number; startX: number; startY: number; offset: StickerPoint; at: StickerPoint; active: boolean }

function homeAt(point: StickerPoint, bounds: StickerBounds[]) {
  let best: StickerBounds | null = null
  for (const body of bounds)
    if (point.x >= body.x0 && point.x <= body.x1 && point.y >= body.y0 && point.y <= body.y1 && (!best || body.depth > best.depth)) best = body
  return best?.id ?? null
}

/** Groups directly inside a sticker's home, which it bounces off from outside. */
const obstacles = (home: string | null, bounds: Map<string, StickerBounds>) =>
  [...bounds.values()].filter((obstacle) => obstacle.parent === home && obstacle.id !== home)

/**
 * Where a held sticker goes for a cursor at `p`. It stays inside its home and outside the
 * groups in it, straining through whichever edge it's pulled against, until the cursor gets
 * far enough past the edge to pop it through.
 */
function chaseTarget(body: Body, point: StickerPoint, bounds: Map<string, StickerBounds>, pop: number): StickerPoint {
  const home = body.home ? bounds.get(body.home) : undefined
  if (home) {
    const outsideDistance = Math.hypot(Math.max(home.x0 - point.x, 0, point.x - home.x1), Math.max(home.y0 - point.y, 0, point.y - home.y1))
    if (outsideDistance > pop) {
      body.home = home.parent
      return chaseTarget(body, point, bounds, pop)
    }
    const inside = { x: clamp(point.x, home.x0 + RADIUS, home.x1 - RADIUS), y: clamp(point.y, home.y0 + RADIUS, home.y1 - RADIUS) }
    const pull = Math.hypot(point.x - inside.x, point.y - inside.y)
    if (outsideDistance > 0 && pull > 0) {
      const strain = Math.min(RADIUS, outsideDistance * STRAIN) / pull
      return { x: inside.x + (point.x - inside.x) * strain, y: inside.y + (point.y - inside.y) * strain }
    }
    point = inside
  }
  for (const obstacle of obstacles(body.home, bounds)) {
    if (point.x < obstacle.x0 - RADIUS || point.x > obstacle.x1 + RADIUS || point.y < obstacle.y0 - RADIUS || point.y > obstacle.y1 + RADIUS) continue
    // The side the sticker is on is the edge it presses against.
    const gaps = [obstacle.x0 - body.x, body.x - obstacle.x1, obstacle.y0 - body.y, body.y - obstacle.y1]
    const side = gaps.indexOf(Math.max(...gaps))
    const depth = [point.x - obstacle.x0, obstacle.x1 - point.x, point.y - obstacle.y0, obstacle.y1 - point.y][side]
    if (depth > pop) {
      body.home = obstacle.id
      return chaseTarget(body, point, bounds, pop)
    }
    const strain = Math.min(RADIUS, (depth + RADIUS) * STRAIN)
    if (side === 0) return { x: obstacle.x0 - RADIUS + strain, y: point.y }
    if (side === 1) return { x: obstacle.x1 + RADIUS - strain, y: point.y }
    if (side === 2) return { x: point.x, y: obstacle.y0 - RADIUS + strain }
    return { x: point.x, y: obstacle.y1 + RADIUS - strain }
  }
  return point
}

function bounceOffWalls(body: Body, bounds: Map<string, StickerBounds>) {
  const home = body.home ? bounds.get(body.home) : undefined
  if (home) {
    const wall = (normalX: number, normalY: number) => {
      const normalVelocity = body.velocityX * normalX + body.velocityY * normalY
      if (normalVelocity >= 0) return
      body.velocityX -= (1 + WALL_BOUNCE) * normalVelocity * normalX
      body.velocityY -= (1 + WALL_BOUNCE) * normalVelocity * normalY
      body.spin += (normalX ? body.velocityY : -body.velocityX) * HIT_WOBBLE * 0.5
    }
    const x = clamp(body.x, home.x0 + RADIUS, home.x1 - RADIUS)
    const y = clamp(body.y, home.y0 + RADIUS, home.y1 - RADIUS)
    if (x !== body.x) wall(Math.sign(x - body.x), 0)
    if (y !== body.y) wall(0, Math.sign(y - body.y))
    body.x = x
    body.y = y
  }
  for (const obstacle of obstacles(body.home, bounds)) {
    const deltaX = body.x - clamp(body.x, obstacle.x0, obstacle.x1)
    const deltaY = body.y - clamp(body.y, obstacle.y0, obstacle.y1)
    const distance = Math.hypot(deltaX, deltaY)
    if (distance >= RADIUS) continue
    let normalX: number
    let normalY: number
    let depth: number
    if (distance > 0) {
      normalX = deltaX / distance
      normalY = deltaY / distance
      depth = RADIUS - distance
    } else {
      const sides = [body.x - obstacle.x0, obstacle.x1 - body.x, body.y - obstacle.y0, obstacle.y1 - body.y]
      const side = sides.indexOf(Math.min(...sides))
      ;[normalX, normalY] = [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ][side]
      depth = sides[side] + RADIUS
    }
    body.x += normalX * depth
    body.y += normalY * depth
    const normalVelocity = body.velocityX * normalX + body.velocityY * normalY
    if (normalVelocity < 0) {
      body.velocityX -= (1 + WALL_BOUNCE) * normalVelocity * normalX
      body.velocityY -= (1 + WALL_BOUNCE) * normalVelocity * normalY
    }
  }
}

/** Two stickers bump like pucks. A held one is the mallet: it pushes and never gets pushed. */
function collide(firstBody: Body, secondBody: Body, held: Body | undefined) {
  if (firstBody.home !== secondBody.home || (firstBody.resting && secondBody.resting)) return
  const deltaX = secondBody.x - firstBody.x
  const deltaY = secondBody.y - firstBody.y
  const distance = Math.hypot(deltaX, deltaY)
  if (distance >= RADIUS * 2) return
  const [normalX, normalY] = distance > 1e-6 ? [deltaX / distance, deltaY / distance] : [1, 0]
  const overlap = RADIUS * 2 - distance
  const relativeVelocityX = secondBody.velocityX - firstBody.velocityX
  const relativeVelocityY = secondBody.velocityY - firstBody.velocityY
  const normalVelocity = relativeVelocityX * normalX + relativeVelocityY * normalY
  if (firstBody === held) {
    secondBody.x += normalX * overlap
    secondBody.y += normalY * overlap
    if (normalVelocity < 0) {
      secondBody.velocityX -= (1 + BOUNCE) * normalVelocity * normalX
      secondBody.velocityY -= (1 + BOUNCE) * normalVelocity * normalY
    }
  } else if (secondBody === held) {
    firstBody.x -= normalX * overlap
    firstBody.y -= normalY * overlap
    if (normalVelocity < 0) {
      firstBody.velocityX += (1 + BOUNCE) * normalVelocity * normalX
      firstBody.velocityY += (1 + BOUNCE) * normalVelocity * normalY
    }
  } else {
    firstBody.x -= (normalX * overlap) / 2
    firstBody.y -= (normalY * overlap) / 2
    secondBody.x += (normalX * overlap) / 2
    secondBody.y += (normalY * overlap) / 2
    if (normalVelocity < 0) {
      const impulse = ((1 + BOUNCE) * normalVelocity) / 2
      firstBody.velocityX += impulse * normalX
      firstBody.velocityY += impulse * normalY
      secondBody.velocityX -= impulse * normalX
      secondBody.velocityY -= impulse * normalY
    }
  }
  if (normalVelocity < 0) {
    const tangentialVelocity = relativeVelocityY * normalX - relativeVelocityX * normalY
    firstBody.spin -= tangentialVelocity * HIT_WOBBLE
    secondBody.spin += tangentialVelocity * HIT_WOBBLE
  }
  firstBody.resting = false
  secondBody.resting = false
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
  private reactFlow: ReactFlowInstance | null = null
  private draw: () => void

  constructor(draw: () => void) {
    this.draw = draw
  }

  update(stickers: PlacedSticker[], bounds: StickerBounds[], settle: (moves: StickerMove[]) => void, reactFlow: ReactFlowInstance) {
    this.stickers = stickers
    this.list = bounds
    this.bounds = new Map(bounds.map((body) => [body.id, body]))
    this.settle = settle
    this.reactFlow = reactFlow
    // Asleep, the stickers' own positions have caught up with where the bodies landed.
    if (!this.frame && !this.hold) this.bodies.clear()
  }

  stop() {
    cancelAnimationFrame(this.frame)
    this.frame = 0
  }

  position(sticker: PlacedSticker) {
    const body = this.bodies.get(sticker.id)
    return body ? { x: body.x, y: body.y, lean: body.lean } : { x: sticker.x, y: sticker.y, lean: 0 }
  }

  private newBody(sticker: PlacedSticker): Body {
    return {
      id: sticker.id,
      x: sticker.x,
      y: sticker.y,
      velocityX: 0,
      velocityY: 0,
      lean: 0,
      spin: 0,
      home: homeAt(sticker, this.list),
      fromX: sticker.x,
      fromY: sticker.y,
      resting: true,
    }
  }

  private wake() {
    if (this.frame) return
    if (!this.bodies.size) for (const sticker of this.stickers) this.bodies.set(sticker.id, this.newBody(sticker))
    this.at = performance.now()
    this.frame = requestAnimationFrame(this.step)
  }

  /** A fresh stamp knocks aside whatever it lands on. */
  stamped(id: string) {
    if (reducedMotion()) return
    this.wake()
    const sticker = this.bodies.get(id)
    if (!sticker) return
    for (const body of this.bodies.values()) {
      const distance = Math.hypot(body.x - sticker.x, body.y - sticker.y)
      if (body === sticker || body.home !== sticker.home || distance >= RADIUS * 2) continue
      const angle = Math.random() * 2 * Math.PI
      const [normalX, normalY] =
        distance > 1e-6 ? [(body.x - sticker.x) / distance, (body.y - sticker.y) / distance] : [Math.cos(angle), Math.sin(angle)]
      body.velocityX += normalX * STAMP_KNOCK
      body.velocityY += normalY * STAMP_KNOCK
      body.resting = false
    }
  }

  private flow(event: { clientX: number; clientY: number }) {
    return this.reactFlow ? this.reactFlow.screenToFlowPosition({ x: event.clientX, y: event.clientY }) : { x: event.clientX, y: event.clientY }
  }

  grab(id: string, event: React.PointerEvent) {
    const at = this.flow(event)
    const sticker = this.bodies.get(id) ?? this.stickers.find((candidate) => candidate.id === id)
    if (!sticker) return
    this.hold = {
      id,
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      offset: { x: sticker.x - at.x, y: sticker.y - at.y },
      at: { x: sticker.x, y: sticker.y },
      active: false,
    }
  }

  drag(event: React.PointerEvent) {
    const hold = this.hold
    if (!hold || hold.pointerId !== event.pointerId) return
    if (!hold.active && Math.hypot(event.clientX - hold.startX, event.clientY - hold.startY) < DRAG_SLOP) return
    const at = this.flow(event)
    hold.at = { x: at.x + hold.offset.x, y: at.y + hold.offset.y }
    if (hold.active) return
    hold.active = true
    this.wake()
    const body = this.bodies.get(hold.id)
    if (body) body.resting = false
  }

  release(event: React.PointerEvent) {
    if (this.hold?.pointerId !== event.pointerId) return
    this.hold = null
  }

  private step = (now: number) => {
    const elapsed = Math.min(MAX_FRAME_MILLISECONDS, now - this.at)
    this.at = now
    const still = reducedMotion()
    const ids = new Set(this.stickers.map((sticker) => sticker.id))
    for (const id of this.bodies.keys()) if (!ids.has(id)) this.bodies.delete(id)
    for (const sticker of this.stickers) {
      const body = this.bodies.get(sticker.id)
      if (!body) this.bodies.set(sticker.id, this.newBody(sticker))
      // Untouched stickers keep riding along with the card under them.
      else if (body.resting && body.x === body.fromX && body.y === body.fromY) {
        body.x = body.fromX = sticker.x
        body.y = body.fromY = sticker.y
      }
    }
    const all = [...this.bodies.values()]
    const held = this.hold?.active ? this.bodies.get(this.hold.id) : undefined
    const pop = POP_DISTANCE / (this.reactFlow?.getZoom() ?? 1)
    const steps = Math.max(1, Math.ceil(elapsed / STEP_MILLISECONDS))
    const stepDuration = elapsed / steps
    const keep = Math.pow(FRICTION, stepDuration)
    for (let i = 0; i < steps; i++) {
      if (held && this.hold) {
        const targetPosition = chaseTarget(held, this.hold.at, this.bounds, pop)
        if (still) Object.assign(held, { x: targetPosition.x, y: targetPosition.y, velocityX: 0, velocityY: 0 })
        else {
          held.velocityX += (CHASE * (targetPosition.x - held.x) - CHASE_DAMPING * held.velocityX) * stepDuration
          held.velocityY += (CHASE * (targetPosition.y - held.y) - CHASE_DAMPING * held.velocityY) * stepDuration
          held.x += held.velocityX * stepDuration
          held.y += held.velocityY * stepDuration
        }
      }
      if (still) break
      for (const body of all) {
        if (body === held || body.resting) continue
        const speed = Math.hypot(body.velocityX, body.velocityY)
        if (speed > MAX_SPEED) {
          body.velocityX *= MAX_SPEED / speed
          body.velocityY *= MAX_SPEED / speed
        }
        body.x += body.velocityX * stepDuration
        body.y += body.velocityY * stepDuration
        body.velocityX *= keep
        body.velocityY *= keep
        bounceOffWalls(body, this.bounds)
      }
      for (let i = 0; i < all.length; i++) for (let j = i + 1; j < all.length; j++) collide(all[i], all[j], held)
    }
    let awake = !!this.hold
    for (const body of all) {
      const target = body === held && !still ? clamp(body.velocityX * LEAN, -MAX_LEAN, MAX_LEAN) : 0
      body.spin = (body.spin + (target - body.lean) * SPRING) * DAMPING
      body.lean += body.spin
      if (body === held) continue
      if (!body.resting && Math.hypot(body.velocityX, body.velocityY) < REST_SPEED && Math.abs(body.lean) < 0.2 && Math.abs(body.spin) < 0.05) {
        body.velocityX = 0
        body.velocityY = 0
        body.lean = 0
        body.resting = true
      }
      if (!body.resting || Math.abs(body.lean) > 0.2) awake = true
    }
    this.draw()
    if (awake) {
      this.frame = requestAnimationFrame(this.step)
      return
    }
    this.frame = 0
    const moves = all
      .filter((body) => Math.hypot(body.x - body.fromX, body.y - body.fromY) > 0.5)
      .map((body) => ({ id: body.id, x: body.x, y: body.y }))
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
  menu: (event: React.MouseEvent, id: string) => void
}) {
  const reactFlow = useReactFlow()
  const [, redraw] = useState(0)
  const [world] = useState(() => new StickerWorld(() => redraw((count) => count + 1)))
  useLayoutEffect(() => world.update(stickers, bounds, settle, reactFlow))
  useEffect(() => () => world.stop(), [world])

  const seen = useRef<Set<string> | null>(null)
  useEffect(() => {
    const before = seen.current
    seen.current = new Set(stickers.map((sticker) => sticker.id))
    if (before) for (const sticker of stickers) if (sticker.fresh && !before.has(sticker.id)) world.stamped(sticker.id)
  }, [stickers, world])

  return (
    <ViewportPortal>
      {stickers.map((sticker) => {
        const at = world.position(sticker)
        const held = world.hold?.active && world.hold.id === sticker.id
        return (
          <div
            key={sticker.id}
            className={`sticker nopan${sticker.fresh ? ' is-fresh' : ''}${held ? ' is-held' : ''}${interactive ? ' is-interactive' : ''}`}
            style={{ transform: `translate(${at.x}px, ${at.y}px)`, '--tilt': `${sticker.tilt + at.lean}deg` } as CSSProperties}
            onPointerDown={(event) => {
              if (event.button !== 0 || !interactive) return
              event.stopPropagation()
              event.currentTarget.setPointerCapture(event.pointerId)
              world.grab(sticker.id, event)
            }}
            onPointerMove={(event) => world.drag(event)}
            onPointerUp={(event) => world.release(event)}
            onPointerCancel={(event) => world.release(event)}
            onContextMenu={(event) => {
              event.stopPropagation()
              menu(event, sticker.id)
            }}
          >
            <span className="sticker-art">{sticker.kind}</span>
          </div>
        )
      })}
    </ViewportPortal>
  )
}

const WHEEL_RADIUS = 72
const WHEEL_EDGE = 120
const HUB_RADIUS = 30

/**
 * Picks a sticker. Opened by holding S, it follows FigJam: point at one and let go.
 * A quick tap leaves it open, as does opening it from the toolbar, and then any
 * emoji typed or pasted into the middle is loaded. Right-clicking a slot, or
 * clicking an empty one, fills it with the next emoji instead.
 */
export function StickerWheel({
  at,
  held,
  current,
  loadout,
  pick,
  assign,
  close,
}: {
  at: StickerPoint
  held: boolean
  current: string
  loadout: Loadout
  pick: (emoji: string) => void
  assign: (slot: number, emoji: string | null) => void
  close: () => void
}) {
  const [hover, setHover] = useState<number | null>(null)
  const [holding, setHolding] = useState(held)
  const [filling, setFilling] = useState<number | null>(null)
  const field = useRef<HTMLInputElement>(null)
  const center = {
    x: Math.max(WHEEL_EDGE, Math.min(window.innerWidth - WHEEL_EDGE, at.x)),
    y: Math.max(WHEEL_EDGE, Math.min(window.innerHeight - WHEEL_EDGE, at.y)),
  }

  const choose = (slot: number) => {
    const emoji = loadout[slot]
    if (emoji) return pick(emoji)
    setHolding(false)
    setFilling(slot)
  }
  const latest = useRef({ hover, holding, filling, choose, assign, close })
  useLayoutEffect(() => {
    latest.current = { hover, holding, filling, choose, assign, close }
  })

  useEffect(() => {
    if (!holding) field.current?.focus()
  }, [holding, filling])

  useEffect(() => {
    const opened = performance.now()
    const down = (event: KeyboardEvent) => {
      const { hover, filling, choose, assign, close } = latest.current
      const digit = Number(event.key)
      if (event.key === 'Escape') {
        if (filling !== null) setFilling(null)
        else close()
      } else if (/^[1-9]$/.test(event.key) && digit <= WHEEL_SLOTS) choose(digit - 1)
      else if (event.key === 'Enter' && hover !== null) choose(hover)
      else if ((event.key === 'Backspace' || event.key === 'Delete') && filling !== null) {
        assign(filling, null)
        setFilling(null)
      } else if (event.key.toLowerCase() !== 's' || event.target === field.current) return
      event.preventDefault()
      event.stopImmediatePropagation()
    }
    const up = (event: KeyboardEvent) => {
      const { hover, holding, choose, close } = latest.current
      if (!holding || event.key.toLowerCase() !== 's') return
      if (hover !== null) choose(hover)
      else if (performance.now() - opened > 350) close()
      else setHolding(false)
    }
    window.addEventListener('keydown', down, { capture: true })
    window.addEventListener('keyup', up)
    return () => {
      window.removeEventListener('keydown', down, { capture: true })
      window.removeEventListener('keyup', up)
    }
  }, [])

  const track = (event: React.PointerEvent) => {
    const deltaX = event.clientX - center.x
    const deltaY = event.clientY - center.y
    const distance = Math.hypot(deltaX, deltaY)
    if (distance < HUB_RADIUS || distance > WHEEL_EDGE * 1.6) return setHover(null)
    const turn = (Math.atan2(deltaX, -deltaY) / (2 * Math.PI) + 1) % 1
    setHover(Math.round(turn * WHEEL_SLOTS) % WHEEL_SLOTS)
  }

  const typed = (text: string) => {
    const emoji = firstEmoji(text)
    if (!emoji) return
    if (filling === null) return pick(emoji)
    assign(filling, emoji)
    setFilling(null)
  }

  return (
    <div
      className="wheel-backdrop"
      onPointerMove={track}
      onPointerDown={(event) => event.target === event.currentTarget && close()}
      onContextMenu={(event) => {
        event.preventDefault()
        close()
      }}
    >
      <div className="wheel" style={{ left: center.x, top: center.y }} role="menu" aria-label="Stickers">
        {loadout.map((emoji, i) => {
          const angle = (i / WHEEL_SLOTS) * 2 * Math.PI
          const classes = [
            'wheel-item',
            emoji ? '' : 'empty',
            hover === i ? 'hover' : '',
            emoji === current ? 'current' : '',
            filling === i ? 'filling' : '',
          ]
          return (
            <button
              key={i}
              type="button"
              role="menuitem"
              className={classes.filter(Boolean).join(' ')}
              style={{ '--x': `${Math.sin(angle) * WHEEL_RADIUS}px`, '--y': `${-Math.cos(angle) * WHEEL_RADIUS}px`, '--i': i } as CSSProperties}
              title={emoji ? `${emoji} (${i + 1}), right-click to change` : `Empty slot (${i + 1}), click to fill`}
              aria-label={emoji ?? `Empty slot ${i + 1}`}
              onClick={() => choose(i)}
              onContextMenu={(event) => {
                event.preventDefault()
                event.stopPropagation()
                setHolding(false)
                setFilling(i)
              }}
            >
              {emoji}
            </button>
          )
        })}
        <input
          ref={field}
          className="wheel-hub"
          value=""
          placeholder={filling === null ? 'any emoji' : `slot ${filling + 1}`}
          aria-label={filling === null ? 'Stamp any emoji' : `Emoji for slot ${filling + 1}`}
          onChange={(event) => typed(event.target.value)}
        />
        {!holding && (
          <p className="wheel-tip">
            {filling === null
              ? 'Type or paste any emoji, or ⌃⌘Space for all of them. Right-click a slot to change it.'
              : `Type or paste an emoji for slot ${filling + 1}. ⌫ empties it, Esc cancels.`}
          </p>
        )}
      </div>
    </div>
  )
}
