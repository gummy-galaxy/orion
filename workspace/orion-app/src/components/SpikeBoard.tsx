import { useCallback, useEffect, useRef, useState } from 'react'
import { ContextMenu, type MenuItem } from './ContextMenu'
import { SpikeCard, type CardMark } from './SpikeCard'
import { SpikeLinks } from './SpikeLinks'
import { SpikeMinimap } from './SpikeMinimap'
import { SpikePanel, type TaskRun } from './SpikePanel'
import { SpikePointer } from './SpikePointer'
import { CARD_HEIGHT, CARD_WIDTH, CARDS, LINKS, MOVE_ZONE, PRESETS, START_CAMERA } from '../selectionSpike/board'
import { boundsOf } from '../selectionSpike/boundsOf'
import { cardsInBox } from '../selectionSpike/cardsInBox'
import { cardsInCircle } from '../selectionSpike/cardsInCircle'
import { combineSelection } from '../selectionSpike/combineSelection'
import { dealOut } from '../selectionSpike/dealOut'
import { frameCamera } from '../selectionSpike/frameCamera'
import { gatherLinked } from '../selectionSpike/gatherLinked'
import { isTaskDone } from '../selectionSpike/isTaskDone'
import { presetOf } from '../selectionSpike/presetOf'
import { viewOf } from '../selectionSpike/viewOf'
import type { Area, Camera, Combine, Gesture, Point, Positions, TaskId } from '../selectionSpike/types'
import '../selectionSpike/selectionSpike.css'

const START_POSITIONS: Positions = Object.fromEntries(CARDS.map((card) => [card.id, { x: card.x, y: card.y }]))
const LAUNCH = CARDS.filter((card) => card.area === 'launch').map((card) => card.id)
const PILE = CARDS.filter((card) => card.area === 'new').map((card) => card.id)

/** How far a left press travels before it's a drag rather than a click, in screen pixels. */
const DRAG_THRESHOLD = 4
/** How far a right press travels before it pans instead of opening the menu. */
const RIGHT_CLICK_SLOP = 5
const MIN_RADIUS = 24
const MAX_RADIUS = 360
const MAX_HOPS = 4
/** Wheel travel that steps a gather by one hop, so a trackpad's flood of small deltas doesn't skip ahead. */
const HOP_STEP = 40
const NUDGE = 20

type Held = { shift: boolean; alt: boolean; meta: boolean; space: boolean }

type Session = { start: Point; pointer: Point; moved: boolean } & (
  | { kind: 'pan'; camera: Camera }
  | { kind: 'right'; camera: Camera; card: string | null }
  | { kind: 'move'; ids: string[]; from: Positions; card: string; before: Snapshot | null; pressedSelected: boolean }
  | { kind: 'box'; base: ReadonlySet<string>; origin: Point }
  | { kind: 'sweep'; base: ReadonlySet<string>; working: Set<string>; last: Point | null }
  | { kind: 'magnet'; base: ReadonlySet<string> }
  | { kind: 'gather'; base: ReadonlySet<string>; origin: string; wheel: number }
)

type Snapshot = { positions: Positions; selection: ReadonlySet<string> }

type GatherState = { origin: string; hops: number; leftBehind: ReadonlySet<string>; gathered: ReadonlySet<string> }

type Overlay = {
  marquee?: { x: number; y: number; width: number; height: number }
  brush?: { x: number; y: number; r: number }
  tethers?: { from: Point; to: Point }[]
}

type Props = { initialGesture?: Gesture; showPointer?: boolean }

const NO_KEYS: Held = { shift: false, alt: false, meta: false, space: false }

const centerOf = (position: Point) => ({ x: position.x + CARD_WIDTH / 2, y: position.y + CARD_HEIGHT / 2 })

const combineFor = (held: Held, gesture: Gesture): Combine => {
  if (gesture.modifiers === 'full') return held.alt ? 'subtract' : held.shift ? 'add' : 'replace'

  return held.shift || held.meta ? 'add' : 'replace'
}

const followsLinks = (held: Held, gesture: Gesture) => gesture.modifiers === 'full' && held.meta

const cardAt = (target: EventTarget | null) => (target as HTMLElement | null)?.closest?.('[data-card]')?.getAttribute('data-card') ?? null

/**
 * A fake board for trying mouse-first selection and navigation side by side. It shares no
 * state with the real canvas: the cards, links, and camera all live here.
 */
export function SpikeBoard({ initialGesture = PRESETS[0].gesture, showPointer = false }: Props) {
  const ref = useRef<HTMLDivElement>(null)
  const [gesture, setGesture] = useState(initialGesture)
  const [positions, setPositions] = useState(START_POSITIONS)
  const [selection, setSelection] = useState<ReadonlySet<string>>(new Set())
  const [pending, setPending] = useState<ReadonlySet<string> | null>(null)
  const [camera, setCamera] = useState(START_CAMERA)
  const [size, setSize] = useState({ width: 1200, height: 800 })
  const [held, setHeld] = useState(NO_KEYS)
  const [hover, setHover] = useState<{ x: number; y: number; card: string | null } | null>(null)
  const [radius, setRadius] = useState(70)
  const [hops, setHops] = useState(1)
  const [overlay, setOverlay] = useState<Overlay>({})
  const [moving, setMoving] = useState<string[] | null>(null)
  const [gather, setGather] = useState<GatherState | null>(null)
  const [deal, setDeal] = useState<Positions | null>(null)
  const [animating, setAnimating] = useState(false)
  const [gliding, setGliding] = useState(false)
  const [menu, setMenu] = useState<{ x: number; y: number; items: MenuItem[] } | null>(null)
  const [run, setRun] = useState<TaskRun | null>(null)
  const [results, setResults] = useState<TaskRun[]>([])
  const [now, setNow] = useState(() => Date.now())
  const history = useRef<Snapshot[]>([])
  const session = useRef<Session | null>(null)
  const latest = useRef({ positions, selection, camera, held, radius, hops, gesture, gather, deal, run, size })

  latest.current = { positions, selection, camera, held, radius, hops, gesture, gather, deal, run, size }

  // ---- Camera ----

  useEffect(() => {
    const element = ref.current

    if (!element) return

    const observer = new ResizeObserver(() => setSize({ width: element.clientWidth, height: element.clientHeight }))

    observer.observe(element)

    return () => observer.disconnect()
  }, [])

  const view = viewOf(camera, size)

  const glideTo = (next: Camera) => {
    setGliding(true)
    setCamera(next)
    setTimeout(() => setGliding(false), 320)
  }

  const frame = (ids: Iterable<string>) => {
    const bounds = boundsOf(latest.current.positions, ids)

    if (bounds) glideTo(frameCamera(bounds, latest.current.size.width, latest.current.size.height))
  }

  const goTo = (area: Area) => frame(CARDS.filter((card) => card.area === area).map((card) => card.id))

  const centerOn = (point: Point) => {
    const { camera, size } = latest.current

    setCamera({ ...camera, x: size.width / 2 - point.x * camera.zoom, y: size.height / 2 - point.y * camera.zoom })
  }

  const toWorld = (client: Point) => {
    const box = ref.current!.getBoundingClientRect()
    const { camera } = latest.current

    return { x: (client.x - box.left - camera.x) / camera.zoom, y: (client.y - box.top - camera.y) / camera.zoom }
  }

  const toBoard = (client: Point) => {
    const box = ref.current!.getBoundingClientRect()

    return { x: client.x - box.left, y: client.y - box.top }
  }

  // ---- Selection and history ----

  const commit = (next: { selection?: ReadonlySet<string>; positions?: Positions }, keepGather = false) => {
    history.current.push({ positions: latest.current.positions, selection: latest.current.selection })

    if (next.selection) {
      setSelection(next.selection)
      latest.current.selection = next.selection
    }

    if (next.positions) {
      setPositions(next.positions)
      latest.current.positions = next.positions
    }

    if (!keepGather) setGather(null)
  }

  const undo = () => {
    const snapshot = history.current.pop()

    if (!snapshot) return

    setPositions(snapshot.positions)
    setSelection(snapshot.selection)
    setGather(null)
    setDeal(null)
    setRun((current) => (current && current.seconds === undefined ? { ...current, undos: current.undos + 1 } : current))
  }

  const countCancel = () => setRun((current) => (current && current.seconds === undefined ? { ...current, cancels: current.cancels + 1 } : current))

  const withLinks = (ids: Iterable<string>, keys: Held) => (followsLinks(keys, latest.current.gesture) ? gatherLinked(LINKS, ids, 1) : new Set(ids))

  const commitGather = (origin: string, gathered: ReadonlySet<string>, nextSelection: ReadonlySet<string>) => {
    commit({ selection: nextSelection }, true)
    setGather({ origin, hops: latest.current.hops, leftBehind: new Set(), gathered })
  }

  const leaveBehind = (id: string) => {
    const current = latest.current.gather

    if (!current) return

    const leftBehind = new Set(current.leftBehind).add(id)
    const gathered = gatherLinked(LINKS, [current.origin], current.hops, leftBehind)
    const dropped = new Set([...current.gathered].filter((other) => !gathered.has(other)))

    commit({ selection: new Set([...latest.current.selection].filter((other) => !dropped.has(other))) }, true)
    setGather({ ...current, leftBehind, gathered })
  }

  const leaveBehindRef = useRef(leaveBehind)

  leaveBehindRef.current = leaveBehind

  const stableLeaveBehind = useCallback((id: string) => leaveBehindRef.current(id), [])

  // ---- Dealing out a pile ----

  const startDeal = (ids: string[]) => {
    if (ids.length < 2) return

    const bounds = boundsOf(latest.current.positions, ids)!
    const targets = dealOut(latest.current.positions, ids, { x: bounds.x0, y: bounds.y0 })
    const all = boundsOf(
      { ...latest.current.positions, ...Object.fromEntries(Object.entries(targets).map(([id, target]) => [`${id}:target`, target])) },
      [...ids, ...Object.keys(targets).map((id) => `${id}:target`)],
    )!
    const { x0, y0, x1, y1 } = viewOf(latest.current.camera, latest.current.size)

    setDeal(targets)

    // Every ghost has to be on screen before anything moves, so a deal that reaches past the view frames itself first.
    if (all.x0 < x0 || all.y0 < y0 || all.x1 > x1 || all.y1 > y1) glideTo(frameCamera(all, latest.current.size.width, latest.current.size.height))
  }

  const confirmDeal = () => {
    const targets = latest.current.deal

    if (!targets) return

    setDeal(null)
    setAnimating(true)
    commit({ positions: { ...latest.current.positions, ...targets } }, true)
    setTimeout(() => setAnimating(false), 360)
  }

  // ---- Gestures ----

  /** Recomputes what an active gesture would do with the pointer at `client` and the keys in `keys`. */
  const evaluate = (active: Session, client: Point, keys: Held) => {
    const { positions, camera, radius, hops, gesture } = latest.current
    const world = toWorld(client)
    const board = toBoard(client)
    const combine = combineFor(keys, gesture)

    active.pointer = client

    switch (active.kind) {
      case 'box': {
        const box = {
          x0: Math.min(active.origin.x, world.x),
          y0: Math.min(active.origin.y, world.y),
          x1: Math.max(active.origin.x, world.x),
          y1: Math.max(active.origin.y, world.y),
        }
        const corner = { x: active.origin.x * camera.zoom + camera.x, y: active.origin.y * camera.zoom + camera.y }

        setPending(combineSelection(active.base, withLinks(cardsInBox(positions, box), keys), combine))
        setOverlay({
          marquee: {
            x: Math.min(corner.x, board.x),
            y: Math.min(corner.y, board.y),
            width: Math.abs(board.x - corner.x),
            height: Math.abs(board.y - corner.y),
          },
        })
        break
      }

      case 'sweep': {
        const reach = radius / camera.zoom
        const from = active.last ?? world
        const steps = Math.max(1, Math.ceil(Math.hypot(world.x - from.x, world.y - from.y) / (reach / 2)))

        // Samples along the path, so a quick flick still paints everything it passed over.
        for (let step = 1; step <= steps; step++) {
          const point = { x: from.x + ((world.x - from.x) * step) / steps, y: from.y + ((world.y - from.y) * step) / steps }

          for (const id of withLinks(cardsInCircle(positions, point, reach), keys)) {
            if (combine === 'subtract') active.working.delete(id)
            else active.working.add(id)
          }
        }

        active.last = world
        setPending(new Set(active.working))
        setOverlay({ brush: { x: board.x, y: board.y, r: radius } })
        break
      }

      case 'magnet': {
        const hits = cardsInCircle(positions, world, radius / camera.zoom)

        setPending(combineSelection(active.base, withLinks(hits, keys), combine))
        setOverlay({
          brush: { x: board.x, y: board.y, r: radius },
          tethers: hits.map((id) => ({ from: world, to: centerOf(positions[id]) })),
        })
        break
      }

      case 'gather': {
        const gathered = gatherLinked(LINKS, [active.origin], hops)
        const from = centerOf(positions[active.origin])

        setPending(combineSelection(active.base, gathered, combine))
        setOverlay({ tethers: [...gathered].filter((id) => id !== active.origin).map((id) => ({ from, to: centerOf(positions[id]) })) })
        break
      }

      default:
    }
  }

  const keysOf = (event: { shiftKey: boolean; altKey: boolean; metaKey: boolean; ctrlKey: boolean }): Held => ({
    shift: event.shiftKey,
    alt: event.altKey,
    meta: event.metaKey || event.ctrlKey,
    space: latest.current.held.space,
  })

  const endSession = () => {
    session.current = null
    setPending(null)
    setOverlay({})
    setMoving(null)
  }

  const cancel = () => {
    const active = session.current

    if (active) {
      if (active.kind === 'move' && active.moved) setPositions({ ...latest.current.positions, ...active.from })

      if (active.kind === 'pan' || active.kind === 'right') setCamera(active.camera)

      endSession()
      countCancel()

      return
    }

    if (latest.current.deal) {
      setDeal(null)
      countCancel()

      return
    }

    if (latest.current.selection.size > 0) commit({ selection: new Set() })
  }

  const openMenu = (client: Point, card: string | null) => {
    let current = latest.current.selection

    if (card && !current.has(card)) {
      current = new Set([card])
      commit({ selection: current })
    }

    const items: MenuItem[] = card
      ? [
          {
            label: 'Select linked cards',
            hint: 'L',
            run: () => {
              const gathered = gatherLinked(LINKS, [card], 1)

              latest.current.hops = 1
              setHops(1)
              commitGather(card, gathered, gathered)
            },
          },
          { label: 'Remove from selection', hint: '⇧↵', run: () => commit({ selection: new Set([...current].filter((id) => id !== card)) }) },
          ...(current.size > 1 ? [{ label: `Deal out ${current.size} cards`, hint: 'D', run: () => startDeal([...current]) }] : []),
          'divider',
          { label: 'Frame selection', hint: 'F', run: () => frame(current) },
        ]
      : [
          { label: 'Select all', hint: '⌘A', run: () => commit({ selection: new Set(CARDS.map((each) => each.id)) }) },
          { label: 'Select new cards', run: () => commit({ selection: new Set(PILE) }) },
          { label: 'Deal out new cards', run: () => startDeal(PILE) },
          'divider',
          { label: 'Frame everything', hint: 'F', run: () => frame(CARDS.map((each) => each.id)) },
        ]

    setMenu({ x: client.x, y: client.y, items })
  }

  const onPointerDown = (event: React.PointerEvent) => {
    const { selection, positions, camera, gesture, held } = latest.current
    const client = { x: event.clientX, y: event.clientY }
    const keys = keysOf(event)
    const card = cardAt(event.target)
    const base = { start: client, pointer: client, moved: false }

    if (session.current) return

    if (latest.current.deal) {
      setDeal(null)
      countCancel()
    }

    ref.current!.setPointerCapture(event.pointerId)

    if (event.button === 1 || (event.button === 0 && held.space)) {
      event.preventDefault()
      session.current = { ...base, kind: 'pan', camera }

      return
    }

    if (event.button === 2) {
      if (gesture.rightDrag === 'pan') session.current = { ...base, kind: 'right', camera, card }

      return
    }

    if (event.button !== 0) return

    if (card) {
      if (gesture.leftDrag === 'gather' && !(selection.has(card) && selection.size > 1)) {
        session.current = { ...base, kind: 'gather', base: selection, origin: card, wheel: 0 }
        evaluate(session.current, client, keys)

        return
      }

      const before = { positions, selection }
      const combine = combineFor(keys, gesture)
      let ids = selection

      // Pressing a card that isn't selected selects it right away, so a drag carries it; the release records the change.
      if (!selection.has(card)) {
        if (combine === 'subtract') return

        ids = combineSelection(selection, withLinks([card], keys), combine)
        latest.current.selection = ids
        setSelection(ids)
        setGather(null)
      }

      session.current = {
        ...base,
        kind: 'move',
        ids: [...ids],
        from: Object.fromEntries([...ids].map((id) => [id, positions[id]])),
        card,
        before,
        pressedSelected: selection.has(card),
      }
      setMoving([...ids])

      return
    }

    if (gesture.leftDrag === 'sweep') {
      const working = new Set(combineFor(keys, gesture) === 'replace' ? [] : selection)

      session.current = { ...base, kind: 'sweep', base: selection, working, last: null }
    } else if (gesture.leftDrag === 'magnet') session.current = { ...base, kind: 'magnet', base: selection }
    else session.current = { ...base, kind: 'box', base: selection, origin: toWorld(client) }
  }

  const onPointerMove = (event: React.PointerEvent) => {
    const client = { x: event.clientX, y: event.clientY }
    const active = session.current

    if (!active) {
      const board = toBoard(client)

      setHover({ ...board, card: cardAt(event.target) })

      return
    }

    const distance = Math.hypot(client.x - active.start.x, client.y - active.start.y)

    if (!active.moved && distance < (active.kind === 'right' ? RIGHT_CLICK_SLOP : DRAG_THRESHOLD)) return

    active.moved = true
    active.pointer = client

    switch (active.kind) {
      case 'pan':
      case 'right':
        setCamera({ ...active.camera, x: active.camera.x + client.x - active.start.x, y: active.camera.y + client.y - active.start.y })
        break

      case 'move': {
        const { zoom } = latest.current.camera
        const dx = (client.x - active.start.x) / zoom
        const dy = (client.y - active.start.y) / zoom

        setPositions((current) => ({
          ...current,
          ...Object.fromEntries(active.ids.map((id) => [id, { x: active.from[id].x + dx, y: active.from[id].y + dy }])),
        }))
        break
      }

      case 'gather': {
        // Dragging a gather carries what it picked up.
        const { positions, hops } = latest.current
        const gathered = gatherLinked(LINKS, [active.origin], hops)
        const next = combineSelection(active.base, gathered, combineFor(keysOf(event), latest.current.gesture))

        commitGather(active.origin, gathered, next)
        session.current = {
          start: active.start,
          pointer: client,
          moved: true,
          kind: 'move',
          ids: [...next],
          from: Object.fromEntries([...next].map((id) => [id, positions[id]])),
          card: active.origin,
          // The gather already recorded the selection, and the drag's positions go with it.
          before: null,
          pressedSelected: false,
        }
        setPending(null)
        setOverlay({})
        setMoving([...next])
        break
      }

      default:
        evaluate(active, client, keysOf(event))
    }
  }

  const onPointerUp = (event: React.PointerEvent) => {
    const active = session.current
    const client = { x: event.clientX, y: event.clientY }

    if (!active) return

    const keys = keysOf(event)
    const { selection, gesture } = latest.current

    endSession()

    switch (active.kind) {
      case 'right':
        if (!active.moved) openMenu(client, active.card)

        break

      case 'move': {
        if (!active.pressedSelected || active.moved) {
          if (active.before) history.current.push(active.before)

          break
        }

        // A click on a selected card, as today: alone it selects only that card, and a modifier changes the rest.
        const combine = combineFor(keys, gesture)

        if (combine === 'replace') commit({ selection: withLinks([active.card], keys) })
        else if (combine === 'subtract' || (gesture.modifiers === 'baseline' && combine === 'add'))
          commit({ selection: new Set([...selection].filter((id) => id !== active.card)) })
        else commit({ selection: combineSelection(selection, withLinks([active.card], keys), 'add') })

        break
      }

      case 'gather': {
        const gathered = gatherLinked(LINKS, [active.origin], latest.current.hops)

        commitGather(active.origin, gathered, combineSelection(active.base, gathered, combineFor(keys, gesture)))
        break
      }

      case 'box':
      case 'sweep':

      case 'magnet': {
        if (!active.moved) {
          if (combineFor(keys, gesture) === 'replace' && selection.size > 0) commit({ selection: new Set() })

          break
        }

        if (active.kind === 'sweep') commit({ selection: new Set(active.working) })
        else evaluateAndCommit(active, client, keys)

        break
      }

      default:
    }
  }

  const evaluateAndCommit = (active: Session, client: Point, keys: Held) => {
    const { positions, camera, radius, gesture } = latest.current
    const world = toWorld(client)
    const combine = combineFor(keys, gesture)

    if (active.kind === 'box') {
      const box = {
        x0: Math.min(active.origin.x, world.x),
        y0: Math.min(active.origin.y, world.y),
        x1: Math.max(active.origin.x, world.x),
        y1: Math.max(active.origin.y, world.y),
      }

      commit({ selection: combineSelection(active.base, withLinks(cardsInBox(positions, box), keys), combine) })
    } else if (active.kind === 'magnet')
      commit({ selection: combineSelection(active.base, withLinks(cardsInCircle(positions, world, radius / camera.zoom), keys), combine) })
  }

  const onContextMenu = (event: React.MouseEvent) => {
    event.preventDefault()

    // Today's menu opens on press, the way macOS opens it. With right-drag pan it waits for the release.
    if (latest.current.gesture.rightDrag === 'menu') openMenu({ x: event.clientX, y: event.clientY }, cardAt(event.target))
  }

  // ---- Wheel and keys ----

  const onWheel = (event: WheelEvent) => {
    const active = session.current

    event.preventDefault()

    if (active && (active.kind === 'sweep' || active.kind === 'magnet')) {
      const next = Math.min(MAX_RADIUS, Math.max(MIN_RADIUS, latest.current.radius * (event.deltaY < 0 ? 1.12 : 1 / 1.12)))

      latest.current.radius = next
      setRadius(next)

      if (active.moved) evaluate(active, active.pointer, keysOf(event))
      else setOverlay({ brush: { ...toBoard(active.pointer), r: next } })

      return
    }

    if (active?.kind === 'gather') {
      active.wheel += event.deltaY

      if (Math.abs(active.wheel) < HOP_STEP) return

      const next = Math.min(MAX_HOPS, Math.max(0, latest.current.hops + (active.wheel < 0 ? 1 : -1)))

      active.wheel = 0
      latest.current.hops = next
      setHops(next)
      evaluate(active, active.pointer, keysOf(event))

      return
    }

    if (active) return

    const { camera } = latest.current

    if (event.ctrlKey || event.metaKey) {
      const point = toBoard({ x: event.clientX, y: event.clientY })
      const zoom = Math.min(1.5, Math.max(0.15, camera.zoom * Math.exp(-event.deltaY * 0.01)))

      setCamera({ zoom, x: point.x - ((point.x - camera.x) * zoom) / camera.zoom, y: point.y - ((point.y - camera.y) * zoom) / camera.zoom })
    } else setCamera({ ...camera, x: camera.x - event.deltaX, y: camera.y - event.deltaY })
  }

  const setKeys = (keys: Held) => {
    latest.current.held = keys
    setHeld(keys)

    const active = session.current

    // A modifier pressed or let go mid-gesture changes it on the next frame, without waiting for the pointer to move.
    if (active && active.moved && (active.kind === 'box' || active.kind === 'magnet')) evaluate(active, active.pointer, keys)

    if (active && active.kind === 'gather') evaluate(active, active.pointer, keys)
  }

  const onKeyDown = (event: KeyboardEvent) => {
    const { selection, positions, held } = latest.current
    const focused = cardAt(document.activeElement)
    const onButton = (event.target as HTMLElement).tagName === 'BUTTON'

    if ((event.target as HTMLElement).tagName === 'INPUT') return

    if (event.key === 'Shift' || event.key === 'Alt' || event.key === 'Meta' || event.key === 'Control') {
      setKeys({ ...held, shift: event.shiftKey, alt: event.altKey, meta: event.metaKey || event.ctrlKey })

      return
    }

    if (event.key === ' ' && !onButton) {
      event.preventDefault()

      if (!held.space) setKeys({ ...held, space: true })

      return
    }

    const preset = PRESETS.find((each) => each.key === event.key)

    if (preset && !event.metaKey && !event.ctrlKey) return setGesture(preset.gesture)

    if (event.key === 'Escape') {
      if (menu) return

      return cancel()
    }

    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'z') {
      event.preventDefault()

      return undo()
    }

    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'a') {
      event.preventDefault()

      return commit({ selection: new Set(CARDS.map((card) => card.id)) })
    }

    if (event.metaKey || event.ctrlKey || session.current) return

    if (event.key === 'Enter') {
      if (latest.current.deal) return confirmDeal()

      if (!focused) return

      event.preventDefault()

      return commit({
        selection: event.shiftKey ? combineSelection(selection, [focused], selection.has(focused) ? 'subtract' : 'add') : new Set([focused]),
      })
    }

    const key = event.key.toLowerCase()

    if (key === 'l' && selection.size > 0) return commit({ selection: gatherLinked(LINKS, selection, 1) })

    if (key === 'd') return startDeal([...selection])

    if (key === 'f') return frame(selection.size > 0 ? selection : CARDS.map((card) => card.id))

    const arrows: Record<string, Point> = {
      ArrowLeft: { x: -1, y: 0 },
      ArrowRight: { x: 1, y: 0 },
      ArrowUp: { x: 0, y: -1 },
      ArrowDown: { x: 0, y: 1 },
    }
    const arrow = arrows[event.key]

    if (!arrow) return

    event.preventDefault()

    const step = event.shiftKey ? NUDGE * 5 : NUDGE

    if (selection.size === 0) {
      const { camera } = latest.current

      return setCamera({ ...camera, x: camera.x - arrow.x * step * 4, y: camera.y - arrow.y * step * 4 })
    }

    commit(
      {
        positions: {
          ...positions,
          ...Object.fromEntries([...selection].map((id) => [id, { x: positions[id].x + arrow.x * step, y: positions[id].y + arrow.y * step }])),
        },
      },
      true,
    )
  }

  const onKeyUp = (event: KeyboardEvent) => {
    const { held } = latest.current

    if (event.key === ' ') {
      if ((event.target as HTMLElement).tagName !== 'BUTTON') event.preventDefault()

      return setKeys({ ...held, space: false })
    }

    if (event.key === 'Shift' || event.key === 'Alt' || event.key === 'Meta' || event.key === 'Control')
      setKeys({ ...held, shift: event.shiftKey, alt: event.altKey, meta: event.metaKey || event.ctrlKey })
  }

  const handlers = useRef({ onWheel, onKeyDown, onKeyUp })

  handlers.current = { onWheel, onKeyDown, onKeyUp }

  useEffect(() => {
    const element = ref.current!
    const wheel = (event: WheelEvent) => handlers.current.onWheel(event)
    const keyDown = (event: KeyboardEvent) => handlers.current.onKeyDown(event)
    const keyUp = (event: KeyboardEvent) => handlers.current.onKeyUp(event)
    const blur = () => setHeld(NO_KEYS)

    element.addEventListener('wheel', wheel, { passive: false })
    window.addEventListener('keydown', keyDown)
    window.addEventListener('keyup', keyUp)
    window.addEventListener('blur', blur)

    return () => {
      element.removeEventListener('wheel', wheel)
      window.removeEventListener('keydown', keyDown)
      window.removeEventListener('keyup', keyUp)
      window.removeEventListener('blur', blur)
    }
  }, [])

  const focusCardRef = useRef((_id: string) => {})

  focusCardRef.current = (id: string) => {
    const element = document.activeElement as HTMLElement | null

    // Only keyboard focus moves the camera: a click never pans the board under the pointer.
    if (!element?.matches(':focus-visible')) return

    const position = latest.current.positions[id]
    const { x0, y0, x1, y1 } = view

    if (position.x < x0 || position.y < y0 || position.x + CARD_WIDTH > x1 || position.y + CARD_HEIGHT > y1) centerOn(centerOf(position))
  }

  const stableFocusCard = useCallback((id: string) => focusCardRef.current(id), [])

  // ---- Tasks ----

  const reset = () => {
    endSession()
    history.current = []
    setPositions(START_POSITIONS)
    setSelection(new Set())
    setGather(null)
    setDeal(null)
    setCamera(START_CAMERA)
  }

  const startTask = (task: TaskId) => {
    reset()

    if (task === 'move') setSelection(new Set(LAUNCH))

    const startedAt = Date.now()

    setNow(startedAt)
    setRun({ task, preset: presetOf(gesture)?.label ?? 'Custom', startedAt, undos: 0, cancels: 0 })
  }

  useEffect(() => {
    if (!run || run.seconds !== undefined || session.current) return

    if (!isTaskDone(run.task, { selection, positions, start: START_POSITIONS, view })) return

    const done = { ...run, preset: presetOf(gesture)?.label ?? 'Custom', seconds: (Date.now() - run.startedAt) / 1000 }

    setRun(done)
    setResults((current) => [...current, done])
  })

  useEffect(() => {
    if (!run || run.seconds !== undefined) return

    const timer = setInterval(() => setNow(Date.now()), 100)

    return () => clearInterval(timer)
  }, [run])

  // ---- What the next action would do ----

  const active = session.current
  const marks = new Map<string, CardMark>()
  let tethers = overlay.tethers ?? []
  let brush = overlay.brush
  let chip: string | null = null
  let origin: string | null = active?.kind === 'gather' ? active.origin : null

  if (pending) {
    for (const card of CARDS) {
      if (pending.has(card.id) && !selection.has(card.id)) marks.set(card.id, 'will-add')
      else if (!pending.has(card.id) && selection.has(card.id)) marks.set(card.id, 'will-remove')
    }
  } else if (moving) moving.forEach((id) => marks.set(id, 'will-move'))
  else if (!active && hover && !deal) {
    const hovered = hover.card
    const world = { x: (hover.x - camera.x) / camera.zoom, y: (hover.y - camera.y) / camera.zoom }

    if (hovered && selection.has(hovered) && selection.size > 1) {
      selection.forEach((id) => marks.set(id, 'will-move'))
      chip = `Drag moves ${selection.size}`
    } else if (hovered && gesture.leftDrag === 'gather') {
      const gathered = gatherLinked(LINKS, [hovered], hops)

      gathered.forEach((id) => id !== hovered && marks.set(id, 'in-reach'))
      origin = hovered
      tethers = [...gathered].filter((id) => id !== hovered).map((id) => ({ from: centerOf(positions[hovered]), to: centerOf(positions[id]) }))
      chip = `${hops} hop${hops === 1 ? '' : 's'} · press for ${gathered.size}`
    } else if (!hovered && !held.space && (gesture.leftDrag === 'sweep' || gesture.leftDrag === 'magnet')) {
      cardsInCircle(positions, world, radius / camera.zoom).forEach((id) => marks.set(id, 'in-reach'))
      brush = { x: hover.x, y: hover.y, r: radius }
    }
  }

  if (active?.kind === 'sweep' || active?.kind === 'magnet') chip = `${Math.round(radius)} px · scroll to resize`

  if (active?.kind === 'gather') chip = `${hops} hop${hops === 1 ? '' : 's'} · scroll for more · drag to carry`

  if (active?.kind === 'move' && active.moved) chip = `Moving ${active.ids.length}`

  const combine = combineFor(held, gesture)
  const keyChip = [combine === 'add' && '+ add', combine === 'subtract' && '− take away', followsLinks(held, gesture) && '⛓ linked']
    .filter(Boolean)
    .join(' ')
  const chipAt = active ? toBoardSafe(active.pointer) : hover

  function toBoardSafe(client: Point) {
    const box = ref.current?.getBoundingClientRect()

    return box ? { x: client.x - box.left, y: client.y - box.top } : null
  }

  const panning = active?.kind === 'pan' || (active?.kind === 'right' && active.moved)
  const boardClass = [
    'spike-board',
    panning ? 'is-panning' : held.space && 'is-pan-ready',
    !active && (gesture.leftDrag === 'sweep' || gesture.leftDrag === 'magnet') && 'is-brush',
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <div className="spike-root">
      <SpikePanel
        gesture={gesture}
        setGesture={setGesture}
        run={run}
        results={results}
        now={now}
        startTask={startTask}
        goTo={goTo}
        undo={undo}
        reset={reset}
      />
      <div
        ref={ref}
        className={boardClass}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={() => cancel()}
        onPointerLeave={() => setHover(null)}
        onContextMenu={onContextMenu}
      >
        <div
          className={['spike-world', animating && 'is-animating', gliding && 'is-gliding'].filter(Boolean).join(' ')}
          style={{ transform: `translate(${camera.x}px, ${camera.y}px) scale(${camera.zoom})` }}
        >
          {run?.task === 'move' && (
            <div
              className="spike-zone"
              style={{ left: MOVE_ZONE.x0, top: MOVE_ZONE.y0, width: MOVE_ZONE.x1 - MOVE_ZONE.x0, height: MOVE_ZONE.y1 - MOVE_ZONE.y0 }}
            >
              Move Launch here
            </div>
          )}
          <SpikeLinks links={LINKS} positions={positions} tethers={tethers} />
          {CARDS.map((card) => (
            <SpikeCard
              key={card.id}
              id={card.id}
              title={card.title}
              area={card.area}
              x={positions[card.id].x}
              y={positions[card.id].y}
              selected={selection.has(card.id)}
              mark={marks.get(card.id) ?? 'none'}
              origin={origin === card.id}
              leaveBehind={
                !active && gather && gather.origin !== card.id && gather.gathered.has(card.id) && selection.has(card.id)
                  ? stableLeaveBehind
                  : undefined
              }
              onFocusCard={stableFocusCard}
            />
          ))}
          {deal &&
            Object.entries(deal).map(([id, target]) => (
              <div key={id} className="spike-ghost" style={{ transform: `translate(${target.x}px, ${target.y}px)` }}>
                {CARDS.find((card) => card.id === id)?.title}
              </div>
            ))}
        </div>
        {overlay.marquee && (
          <div
            className="spike-marquee"
            style={{
              transform: `translate(${overlay.marquee.x}px, ${overlay.marquee.y}px)`,
              width: overlay.marquee.width,
              height: overlay.marquee.height,
            }}
          />
        )}
        {brush && (
          <div
            className={active ? 'spike-brush is-active' : 'spike-brush'}
            style={{ left: brush.x, top: brush.y, width: brush.r * 2, height: brush.r * 2 }}
          />
        )}
        {chipAt && (chip || keyChip) && (
          <div className="spike-chip" style={{ left: chipAt.x + 18, top: chipAt.y + 20 }}>
            {[keyChip, chip].filter(Boolean).join(' · ')}
          </div>
        )}
        {deal && (
          <div className="spike-deal panel" onPointerDown={(event) => event.stopPropagation()}>
            Deal {Object.keys(deal).length} cards into open space nearby? Nothing settled moves.
            <button type="button" className="current" onClick={confirmDeal}>
              ↵ Deal
            </button>
            <button
              type="button"
              onClick={() => {
                setDeal(null)
                countCancel()
              }}
            >
              Esc Cancel
            </button>
          </div>
        )}
        <SpikeMinimap positions={positions} view={view} selection={selection} jump={centerOn} />
      </div>
      {menu && <ContextMenu x={menu.x} y={menu.y} items={menu.items} close={() => setMenu(null)} />}
      {showPointer && <SpikePointer />}
    </div>
  )
}
