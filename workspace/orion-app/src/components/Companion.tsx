import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { clipRect, pickPerch, type Hint, type Mood, type PerchTarget } from '../companion'
import { motionReduced } from '../motion'
import { CompanionStar } from './CompanionStar'
import { StatusIcon } from './StatusIcon'

type Props = {
  /** Everything it could perch on right now, in canvas pixels. Read a few times a second, never each frame. */
  targets: () => readonly PerchTarget[]
  /** What to say once perched, or null to perch quietly. */
  describe: (id: string) => Hint | null
  /** A sync starting cheers it up. */
  syncing?: boolean
  /** While the window is in the background, it stops moving. */
  paused?: boolean
}

type Spring = { width: number; height: number; stiffness: number; damping: number; offset: [number, number] }
type Body = { x: number; y: number; velocityX: number; velocityY: number; lean: number }
type Part = 'main' | 'left' | 'right'

// The body springs toward its perch; the side stars follow on stiff, critically damped springs so they trail only a
// little. Their damping eases off only when the body moves very fast, so a swing-back is possible but rare.
const PARTS: Record<Part, Spring> = {
  main: { width: 40, height: 64, stiffness: 260, damping: 0.95, offset: [0, 0] },
  left: { width: 21, height: 34, stiffness: 8000, damping: 1, offset: [-30, 12] },
  right: { width: 21, height: 34, stiffness: 7000, damping: 1, offset: [30, 12] },
}
const SIDES = ['left', 'right'] as const
/** Stiff springs need small steps to stay stable, so each frame is split into steps of at most this long. */
const SUBSTEP_SECONDS = 0.004
const MAX_FRAME_SECONDS = 0.033
const CHOOSE_INTERVAL_MS = 120
/** How far below the body's center the tethers attach: under its side points, partway down its core. */
const TETHER_ATTACH = 4
/**
 * The tethers draw in a box this wide that rides along with the body, so a frame repaints only that box rather than an
 * SVG the size of the canvas. They may draw past it while a star trails far behind.
 */
const TETHER_BOX = 160
/** Where it rests when nothing shows: just above the minimap in the bottom-right corner. */
const REST_RIGHT = 56
const REST_BOTTOM = 196
/** It perches above a card's top-right corner, clear of the card's own top-right signal. */
const PERCH_INSET = 18
const PERCH_ABOVE = 32
const PERCH_MIN_TOP = 40
const SLEEP_AFTER_MS = 15000
const DASH_SPEED = 3200
const HINT_GAP = 30
const EDGE_GAP = 8

/** Moods that leave its arms hanging. */
const DROOPY: readonly Mood[] = ['sleepy', 'worried']

/**
 * The logo's three stars as a small creature that perches on the card nearest the pointer and reacts to it. It never
 * takes input, and with motion reduced it holds still in its corner and only says what it would perch on.
 */
export function Companion({ targets, describe, syncing = false, paused = false }: Props) {
  const rootRef = useRef<HTMLDivElement>(null)
  const bodyRef = useRef<HTMLDivElement>(null)
  const leftRef = useRef<HTMLDivElement>(null)
  const rightRef = useRef<HTMLDivElement>(null)
  const tethersRef = useRef<SVGSVGElement>(null)
  const leftTetherRef = useRef<SVGPathElement>(null)
  const rightTetherRef = useRef<SVGPathElement>(null)
  const hintRef = useRef<HTMLDivElement>(null)
  const snoozeRef = useRef<HTMLDivElement>(null)
  const [hint, setHint] = useState<Hint | null>(null)
  const props = useRef({ targets, describe })
  const cheer = useRef<() => void>(() => {})

  useLayoutEffect(() => {
    props.current = { targets, describe }
  })

  useEffect(() => {
    if (syncing) cheer.current()
  }, [syncing])

  // Runs once per pause; the refs are stable and props flow in through props.current.
  useEffect(() => {
    const root = rootRef.current
    const hintElement = hintRef.current
    const snooze = snoozeRef.current
    const stars = { main: bodyRef.current, left: leftRef.current, right: rightRef.current }
    const tetherBox = tethersRef.current
    const tethers = { left: leftTetherRef.current, right: rightTetherRef.current }
    const eyes = stars.main?.querySelector('.eyes')

    if (
      !root ||
      !hintElement ||
      !snooze ||
      !stars.main ||
      !stars.left ||
      !stars.right ||
      !tetherBox ||
      !tethers.left ||
      !tethers.right ||
      !eyes
    ) {
      return
    }

    let perch: string | null = null
    let perchTarget: PerchTarget | null = null
    let pendingMood: Mood = ''
    let baseMood: Mood = ''
    let shownMood: Mood = ''
    let flashMood: { mood: Mood; until: number } = { mood: '', until: 0 }
    let wiggle = { start: 0, until: 0 }
    let sleeping = false
    let lastActivity = performance.now()
    let lastChoice = 0
    let lastFrame = performance.now()
    let settledSeconds = 0
    let hasHint = false
    let landed = false
    let impatience: ReturnType<typeof setTimeout> | undefined
    let pointer: [number, number] | null = null
    let view = root.getBoundingClientRect()
    let frame = 0
    // Read when the hint resizes rather than each frame, since reading it forces a layout.
    let hintWidth = hintElement.offsetWidth
    let shownEyes = ''
    let shownSnooze = ''
    let shownHint = ''
    const hintSize = new ResizeObserver(() => {
      hintWidth = hintElement.offsetWidth
    })

    hintSize.observe(hintElement)
    const timers = new Set<ReturnType<typeof setTimeout>>()

    const later = (callback: () => void, ms: number) => {
      const timer = setTimeout(() => {
        timers.delete(timer)
        callback()
      }, ms)

      timers.add(timer)
    }

    /** Shows a mood for a moment, then falls back to the one that fits its perch. */
    const flash = (mood: Mood, ms: number) => {
      flashMood = { mood, until: performance.now() + ms }
    }

    /** Arms: the side stars bob out of step for a moment. */
    const wave = (ms: number) => {
      const now = performance.now()

      wiggle = { start: now, until: now + ms }
    }

    const armLift = (now: number) => {
      if (now >= wiggle.until) return 0

      const progress = (now - wiggle.start) / (wiggle.until - wiggle.start)

      return Math.sin(((now - wiggle.start) / 1000) * Math.PI * 2 * 4.5) * 10 * Math.sin(Math.PI * progress)
    }

    const showHint = (shown: boolean) => hintElement.classList.toggle('is-on', shown)

    const setMood = (mood: Mood) => {
      if (shownMood) root.classList.remove(`is-${shownMood}`)

      shownMood = mood

      if (mood) root.classList.add(`is-${mood}`)
    }

    cheer.current = () => {
      flash('excited', 1800)
      wave(1300)
    }

    const visibleTargets = () => {
      const shown: PerchTarget[] = []

      for (const target of props.current.targets()) {
        const rect = clipRect(target.rect, view.width, view.height)

        if (rect) shown.push({ id: target.id, rect, top: target.top })
      }

      return shown
    }

    const choose = () => {
      view = root.getBoundingClientRect()

      const x = pointer ? pointer[0] - view.left : view.width / 2
      const y = pointer ? pointer[1] - view.top : view.height / 2
      const shown = visibleTargets()
      const next = pickPerch(shown, x, y, perch)

      perchTarget = shown.find((target) => target.id === next) ?? null

      if (next === perch) return

      perch = next
      landed = false
      clearTimeout(impatience)
      showHint(false)
      baseMood = ''

      const described = next ? props.current.describe(next) : null

      setHint(described)
      hasHint = !!described
      pendingMood = described?.mood ?? ''
    }

    /** Where the body wants to be: above its perch's top-right corner, or resting in the corner of the canvas. */
    const goal = (reduced: boolean): [number, number] => {
      if (perchTarget && !reduced) {
        const { rect, top = rect.top } = perchTarget

        return [Math.min(rect.right - PERCH_INSET, view.width - REST_RIGHT), Math.max(top - PERCH_ABOVE, PERCH_MIN_TOP)]
      }

      return [view.width - REST_RIGHT, Math.max(view.height - REST_BOTTOM, PERCH_MIN_TOP)]
    }

    const bodies = {} as Record<Part, Body>

    {
      const [x, y] = goal(motionReduced())

      for (const part of Object.keys(PARTS) as Part[]) {
        bodies[part] = {
          x: x + PARTS[part].offset[0],
          y: y + PARTS[part].offset[1],
          velocityX: 0,
          velocityY: 0,
          lean: 0,
        }
      }
    }

    const step = (now: number) => {
      const frameSeconds = Math.min(MAX_FRAME_SECONDS, (now - lastFrame) / 1000)
      const seconds = now / 1000
      const reduced = motionReduced()

      lastFrame = now

      if (now - lastChoice > CHOOSE_INTERVAL_MS) {
        choose()
        lastChoice = now
      }

      if (!sleeping && !reduced && now - lastActivity > SLEEP_AFTER_MS) {
        sleeping = true
        landed = false
        showHint(false)
      }

      const [goalX, goalY] = goal(reduced)
      const main = bodies.main
      const steps = Math.max(1, Math.ceil(frameSeconds / SUBSTEP_SECONDS))
      const dt = frameSeconds / steps
      const lift = armLift(now)
      const droop = DROOPY.includes(shownMood) ? 1 : 0
      const sway = shownMood === 'impatient' ? Math.sin(seconds * Math.PI * 2 * 0.85) : 0

      const spring = (body: Body, part: Spring, x: number, y: number, damping = part.damping) => {
        if (reduced) {
          body.x = x
          body.y = y
          body.velocityX = 0
          body.velocityY = 0

          return
        }

        const friction = 2 * damping * Math.sqrt(part.stiffness)

        body.velocityX += (part.stiffness * (x - body.x) - friction * body.velocityX) * dt
        body.velocityY += (part.stiffness * (y - body.y) - friction * body.velocityY) * dt
        body.x += body.velocityX * dt
        body.y += body.velocityY * dt
      }

      for (let i = 0; i < steps; i++) {
        const hover = reduced
          ? 0
          : sleeping
            ? Math.sin(seconds * 1.1) * 2 + 4
            : Math.sin(seconds * 2.2) * 3 * (1 - Math.abs(sway))

        spring(main, PARTS.main, goalX + sway * 6, goalY + hover)

        const loose = Math.max(0, Math.min(1, (Math.hypot(main.velocityX, main.velocityY) - 2600) / 2400))

        for (const side of SIDES) {
          const part = PARTS[side]
          const direction = side === 'left' ? -1 : 1
          const bob = sleeping || reduced ? 0 : Math.sin(seconds * 2.6 + (direction < 0 ? 0 : Math.PI)) * 4

          spring(
            bodies[side],
            part,
            main.x + part.offset[0] - direction * droop * 4,
            main.y + part.offset[1] + bob + direction * lift + droop * 10 - direction * sway * 4,
            part.damping - loose * 0.5,
          )
        }
      }

      for (const part of Object.keys(PARTS) as Part[]) {
        const body = bodies[part]
        const size = PARTS[part]

        body.lean = Math.max(-18, Math.min(18, body.velocityX * 0.03)) + (part === 'main' ? sway * 8 : 0)
        stars[part]!.style.transform =
          `translate(${body.x - size.width / 2}px, ${body.y - size.height / 2}px) rotate(${body.lean}deg)`
      }

      // Tethers are noodles with a little slack: one S-shaped wiggle that sways, goes slacker as a star comes closer,
      // pulls taut as it falls behind, and drags a touch against the star's motion. They turn with the body's lean.
      const angle = (main.lean * Math.PI) / 180
      const attachX = main.x - Math.sin(angle) * TETHER_ATTACH
      const attachY = main.y + Math.cos(angle) * TETHER_ATTACH
      const boxLeft = main.x - TETHER_BOX / 2
      const boxTop = main.y - TETHER_BOX / 2

      tetherBox.style.transform = `translate(${boxLeft}px, ${boxTop}px)`

      for (const side of SIDES) {
        const body = bodies[side]
        const part = PARTS[side]
        const deltaX = attachX - body.x
        const deltaY = attachY - body.y
        const length = Math.hypot(deltaX, deltaY) || 1
        const normalX = -deltaY / length
        const normalY = deltaX / length
        const restLength = Math.hypot(part.offset[0], part.offset[1] - TETHER_ATTACH)
        const slack = Math.max(0, Math.min(1.4, (restLength + 12 - length) / 14))
        const phase = seconds * 2.4 + (side === 'left' ? 0 : 1.7)
        const amplitude = reduced ? 0 : 7 * slack * (0.75 + 0.25 * Math.sin(phase))
        const relative = (body.velocityX - main.velocityX) * normalX + (body.velocityY - main.velocityY) * normalY
        const drag = Math.max(-6, Math.min(6, relative * -0.004)) * slack
        const first = amplitude + drag
        const second = -amplitude * 0.8 + drag
        const point = (x: number, y: number) => `${(x - boxLeft).toFixed(1)} ${(y - boxTop).toFixed(1)}`

        const start = point(body.x, body.y)
        const near = point(body.x + deltaX / 3 + normalX * first, body.y + deltaY / 3 + normalY * first)
        const far = point(body.x + (deltaX * 2) / 3 + normalX * second, body.y + (deltaY * 2) / 3 + normalY * second)

        tethers[side]!.setAttribute('d', `M${start} C${near} ${far} ${point(attachX, attachY)}`)
      }

      // The eyes look where it's heading, and a fast dash startles it.
      const speed = Math.hypot(main.velocityX, main.velocityY)

      if (speed > DASH_SPEED && !sleeping) flash('surprised', 250)

      const mood = sleeping ? 'sleepy' : now < flashMood.until ? flashMood.mood : baseMood

      if (mood !== shownMood) setMood(mood)

      const lookX = speed > 60 ? (main.velocityX / speed) * 6 : sway * 5
      const lookY = speed > 60 ? (main.velocityY / speed) * 5 : 0

      const eyesTransform = `translate(${lookX.toFixed(1)} ${lookY.toFixed(1)})`

      // Moving the eyes repaints the body and its glow, so only when they actually move.
      if (eyesTransform !== shownEyes) {
        eyes.setAttribute('transform', eyesTransform)
        shownEyes = eyesTransform
      }

      // Once it lands, the hint shows along with the mood that goes with it.
      const still = speed < 30 && Math.hypot(goalX - main.x, goalY - main.y) < 10

      settledSeconds = still ? settledSeconds + frameSeconds : 0

      if (perch && !sleeping && settledSeconds > 0.12 && !landed) {
        landed = true
        showHint(hasHint)

        if (reduced) baseMood = ''
        else if (pendingMood === 'wink') {
          const waitingOn = perch

          baseMood = ''
          flash('wink', 900)
          impatience = setTimeout(() => {
            if (perch === waitingOn && baseMood === '') baseMood = 'impatient'
          }, 2600)
        } else baseMood = pendingMood

        if (pendingMood === 'excited' && !reduced) wave(900)
      }

      const snoozeTransform = `translate(${(main.x + 14).toFixed(1)}px, ${(main.y - 36).toFixed(1)}px)`

      if (sleeping && snoozeTransform !== shownSnooze) {
        snooze.style.transform = snoozeTransform
        shownSnooze = snoozeTransform
      }

      // The hint sits to the body's left, over its own perch rather than a neighbor, and flips right near the edge.
      const flipped = main.x - HINT_GAP - hintWidth < EDGE_GAP
      const hintX = flipped ? main.x + HINT_GAP : main.x - HINT_GAP - hintWidth
      const hintTransform = `translate(${hintX.toFixed(1)}px, ${(main.y - 13).toFixed(1)}px)`

      if (hintTransform !== shownHint) {
        hintElement.style.transformOrigin = flipped ? '0% 50%' : '100% 50%'
        hintElement.style.transform = hintTransform
        shownHint = hintTransform
      }

      if (!paused) frame = requestAnimationFrame(step)
    }

    const wake = () => {
      lastActivity = performance.now()

      if (!sleeping) return

      sleeping = false
      flash('surprised', 700)
      wave(600)
    }

    const track = (event: PointerEvent) => {
      pointer = [event.clientX, event.clientY]
      wake()
    }

    const blink = () => {
      later(
        () => {
          if (!shownMood && !motionReduced()) {
            root.classList.add('is-blinking')
            later(() => root.classList.remove('is-blinking'), 130)
          }

          blink()
        },
        2600 + Math.random() * 3600,
      )
    }

    const fidget = () => {
      later(
        () => {
          if (!sleeping && !motionReduced()) wave(800)

          fidget()
        },
        8000 + Math.random() * 8000,
      )
    }

    window.addEventListener('pointermove', track, { passive: true })
    window.addEventListener('wheel', wake, { passive: true })
    window.addEventListener('keydown', wake)

    // Paused, it still lands where it belongs, then holds still.
    if (paused) step(performance.now())
    else {
      blink()
      fidget()
      frame = requestAnimationFrame(step)
    }

    return () => {
      cancelAnimationFrame(frame)
      clearTimeout(impatience)
      hintSize.disconnect()

      for (const timer of timers) clearTimeout(timer)

      window.removeEventListener('pointermove', track)
      window.removeEventListener('wheel', wake)
      window.removeEventListener('keydown', wake)

      cheer.current = () => {}
    }
  }, [paused])

  return (
    <div className="companion" ref={rootRef} aria-hidden="true">
      <svg className="companion-tethers" ref={tethersRef} width={TETHER_BOX} height={TETHER_BOX}>
        <path ref={leftTetherRef} />
        <path ref={rightTetherRef} />
      </svg>
      <div className="companion-star is-side" ref={leftRef}>
        <CompanionStar />
      </div>
      <div className="companion-star is-side" ref={rightRef}>
        <CompanionStar />
      </div>
      <div className="companion-star is-body" ref={bodyRef}>
        <CompanionStar face />
      </div>
      <div className="companion-hint" ref={hintRef}>
        {hint?.status && <StatusIcon status={hint.status} />}
        <span>{hint?.text}</span>
      </div>
      <div className="companion-snooze" ref={snoozeRef}>
        <i>z</i>
        <i>z</i>
        <i>z</i>
      </div>
    </div>
  )
}
