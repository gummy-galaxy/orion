import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState, type CSSProperties } from 'react'
import { useAtom, useAtomValue, useSetAtom } from 'jotai'
import {
  Background,
  BackgroundVariant,
  Controls,
  MarkerType,
  MiniMap,
  Panel,
  Position,
  ReactFlow,
  applyNodeChanges,
  useReactFlow,
  useStore,
  useStoreApi,
  type Connection,
  type Edge,
  type EdgeTypes,
  type FinalConnectionState,
  type NodeChange,
  type NodeTypes,
  type Viewport,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import { Companion } from './Companion'
import { ContextMenu, type MenuItem } from './ContextMenu'
import { COMMAND_PREFIX, Palette, type Command } from './Palette'
import { AttentionOverlay, type AttentionTarget } from './AttentionOverlay'
import { ActionsContext, needsAttention, type AttentionMark, type Flow } from '../derive'
import { FocusView, type FocusItem } from './FocusView'
import { reflow } from '../layout'
import { mergeDocs } from '../merge'
import { glide, motionReduced, useSystemMotion } from '../motion'
import {
  absolutePosition,
  ancestors,
  byId,
  groupSelection,
  isCluster,
  isImage,
  isNote,
  isTask,
  normalize,
  getTaskUrl,
  sizeOf,
  getTaskTag,
  relativeTime,
  ungroup,
  type AppNode,
  type ClusterData,
  type GhostNode,
  type GithubSnapshot,
  type ImageNode,
  type Link,
  type TaskData,
} from '../model'
import { DebugBar, type MotionSettings } from './DebugBar'
import { DetailStepper } from './DetailStepper'
import { EmptyCanvas } from './EmptyCanvas'
import { CurveEdge } from './CurveEdge'
import { openExternal } from '../external'
import { readFileSetting, saveFileSetting, saveSettings, type SavedSetting } from '../settings'
import { addRecent, keepExistingNodes, readRecents, recentsKey, type Recent } from '../recents'
import {
  ANIMATIONS,
  COLOR_MODES,
  STATUS_COLORS,
  THEMES,
  applyAppearance,
  colorModeOf,
  readAppearance,
  withMotion,
  writeAppearance,
  type Appearance,
} from '../appearance'
import { SKINS } from '../skins'
import { cardSizeAtom, type CardSize } from '../cardSize'
import { toDisplayed, toStored } from '../skinSpace'
import { ClusterView } from './ClusterView'
import { GhostView } from './GhostView'
import { MiniMapNode } from './MiniMapNode'
import { ImageView } from './ImageView'
import { TaskView } from './TaskView'
import {
  createWorkspace,
  clearFocus,
  compactDoc,
  fetchRemote,
  fingerprint,
  getSyncStatus,
  getWorkspaces,
  importImage,
  load,
  onRemoteChange,
  onSyncStatus,
  onWorkspaceChange,
  onWorkspaceListChange,
  readBrowser,
  reportFocus,
  requestSync,
  save,
  setActiveWorkspace,
  slim,
  type FocusReport,
  type Remote,
  type Saved,
  type SyncStatus,
  type Workspaces,
} from '../persist'
import { Sidebar } from './Sidebar'
import { Settings, type SettingsSection } from './Settings'
import { formatChord, matchesChord, readKeybindings, writeKeybindings, type Keybindings, type ShortcutId } from '../keybindings'
import { ActionBar } from './ActionBar'
import { SnapGuides } from './SnapGuides'
import { useCompanionTargets } from '../useCompanionTargets'
import { useNodeSnapping } from '../useNodeSnapping'
import { useUndo } from '../useUndo'
import { useInspecting } from '../useInspecting'
import {
  attentionAtom,
  collapsedAtom,
  focusedAtom,
  hoverAtom,
  inspectingAtom,
  linksAtom,
  nodesAtom,
  pinnedAtom,
  skinAtom,
  skinStore,
  traceAtom,
  workAtom,
} from '../state'
import { StickerLayer, type PlacedSticker, type StickerBounds, type StickerMove } from './StickerLayer'
import { StickerWheel } from './StickerWheel'
import { FALLBACK_STICKER, loadoutOf, stickerCursor, type Loadout, type Sticker } from '../sticker'
import { Toolbar, type Tool } from './Toolbar'
import { DEFAULT_DETAIL, detailLevels, foldDepth, readDetail, shownLevel, stepDetail, writeDetail, type Detail } from '../detail'
import { MAX_ZOOM, MIN_ZOOM, mapViewportForCardSize, readViewport, writeViewport } from '../viewport'
import { NAVIGATE_EVENT, emptyTrail, leave, travel, type Place, type Trail } from '../navigation'
import { GroupFacts } from './GroupFacts'
import { GroupArrange } from './GroupArrange'
import { NoteInspector } from './NoteInspector'
import { TaskInspector } from './TaskInspector'

type ViewNode = AppNode | GhostNode
type FocusEntry = { viewport: Viewport; moved: boolean }

const nodeTypes: NodeTypes = { task: TaskView, cluster: ClusterView, image: ImageView, ghost: GhostView }
const edgeTypes: EdgeTypes = { default: CurveEdge }
const SIDEBAR_KEY = 'orion:sidebar'
const DEBUG_KEY = 'orion:debug'
const MOTION_KEY = 'orion:motion'
const DEFAULT_MOTION: MotionSettings = { arrows: true, glow: true, pauseWhileMoving: true }

/** Hands back last render's edge wherever the new one draws the same, so React Flow redraws only edges that changed. */
function keepDrawn(drawn: Map<string, { edge: Edge; print: string }>, next: Edge[]): Edge[] {
  const kept = next.map((edge) => {
    const print = JSON.stringify(edge)
    const previous = drawn.get(edge.id)

    return previous?.print === print ? previous : { edge, print }
  })

  drawn.clear()

  for (const entry of kept) drawn.set(entry.edge.id, entry)

  return kept.map((entry) => entry.edge)
}

function readMotion(): MotionSettings {
  try {
    return { ...DEFAULT_MOTION, ...(JSON.parse(localStorage.getItem(MOTION_KEY) ?? '{}') as Partial<MotionSettings>) }
  } catch {
    return DEFAULT_MOTION
  }
}

/** Zoom below which cards are too small for transitions to read, so they're skipped. */
const STILL_ZOOM = 0.45
/** Zoom below which marching arrows and the active glow are too subtle to read, so they stop. */
const QUIET_ZOOM = 0.6
const GHOST_WIDTH = 200
const GHOST_HEIGHT = 62
const GHOST_GAP = 90
/** How much of the outside connections shows when a group opens. */
const GHOST_PEEK = 0.4
const FIT_VERTICAL_MARGIN = 90
const FIT_MAX_ZOOM = 1.25
/** How far across a card, on each side, the selection box has to reach to pick it up. */
const MARQUEE_REACH = 0.25
/** Kept stable: a new object each render would replace the options of any `fitView` call still queued. */
const INITIAL_FIT = { padding: 0.12 }
const ATTEND_DELAY_MS = 150
/** A click on a group waits this long for a second one before it selects. */
const DOUBLE_CLICK_MS = 280
const FOCUS_SIDE_WIDTH = 248
const FOCUS_INSET = 20
const FOCUS_ZOOM = 1.2
/** The focused card sits this far down the canvas, leaving room for its details above. */
const FOCUS_CARD_Y = 0.7
const FOCUS_BOTTOM_GAP = 24
/** Focus moves head straight for the card and start fast. */
const focusMove = () => ({ duration: glide(260), ease: (progress: number) => 1 - Math.pow(1 - progress, 3), interpolate: 'linear' }) as const
const PLACE_GAP = 80
/** Stickers land up to this many degrees off straight. */
const STICKER_TILT = 14
const STICKER_FRESH_MS = 700
/** How far above the toolbar the sticker wheel opens. */
const WHEEL_LIFT = 140
const EDGE_COLOR: Record<Flow, string> = { live: '--edge-hot', held: '--edge-held' }

type Menu = {
  x: number
  y: number
  flow: { x: number; y: number }
  target: { kind: 'pane' } | { kind: 'node'; id: string } | { kind: 'edge'; id: string } | { kind: 'sticker'; id: string }
}

/** Whether the window is in the background, where looping motion only costs power. */
function useAway() {
  const [away, setAway] = useState(() => document.hidden || !document.hasFocus())

  useEffect(() => {
    const update = () => setAway(document.hidden || !document.hasFocus())

    window.addEventListener('focus', update)
    window.addEventListener('blur', update)
    document.addEventListener('visibilitychange', update)

    return () => {
      window.removeEventListener('focus', update)
      window.removeEventListener('blur', update)
      document.removeEventListener('visibilitychange', update)
    }
  }, [])

  return away
}

function readFlag(key: string, fallback: boolean) {
  try {
    const value = localStorage.getItem(key)

    return value === null ? fallback : value === '1'
  } catch {
    return fallback
  }
}

function writeFlag(key: SavedSetting, value: boolean) {
  saveSettings({ [key]: value ? '1' : '0' })
}

const ease = (progress: number) => 1 - Math.pow(1 - progress, 3)
const newId = (prefix: string) => prefix + '-' + Date.now().toString(36) + Math.random().toString(36).slice(2, 5)

function groupFitViewport(group: AppNode, map: Map<string, AppNode>, box: { width: number; height: number }, cardSize: CardSize): Viewport {
  const position = absolutePosition(group, map)
  const size = sizeOf(group, cardSize)
  const width = size.width + 2 * (GHOST_GAP + GHOST_WIDTH * GHOST_PEEK)
  const height = size.height + FIT_VERTICAL_MARGIN * 2
  const zoom = Math.min(box.width / width, box.height / height, FIT_MAX_ZOOM)

  return { x: box.width / 2 - (position.x + size.width / 2) * zoom, y: box.height / 2 - (position.y + size.height / 2) * zoom, zoom }
}

/** Puts a card between the focus columns, a little larger than life. */
function focusViewport(card: AppNode, map: Map<string, AppNode>, box: { width: number; height: number }, cardSize: CardSize): Viewport {
  const position = absolutePosition(card, map)
  const size = sizeOf(card, cardSize)
  const zoom = FOCUS_ZOOM
  const centerY = Math.min(box.height * FOCUS_CARD_Y, box.height - FOCUS_BOTTOM_GAP - (size.height * zoom) / 2)

  return { x: box.width / 2 - (position.x + size.width / 2) * zoom, y: centerY - (position.y + size.height / 2) * zoom, zoom }
}

/**
 * Stacks newly created groups in columns to the right of everything else at the top
 * level, so laying them out never moves groups that were already placed.
 */
function placeBesideExisting(nodes: AppNode[], fresh: Set<string>, cardSize: CardSize): AppNode[] {
  const top = nodes.filter((node) => !node.parentId)
  const settled = top.filter((node) => !fresh.has(node.id))
  const right = settled.length ? Math.max(...settled.map((node) => node.position.x + sizeOf(node, cardSize).width)) : 0
  const topY = settled.length ? Math.min(...settled.map((node) => node.position.y)) : 0
  const columnHeight = Math.max(1600, ...settled.map((node) => node.position.y + sizeOf(node, cardSize).height - topY))
  const placed = new Map<string, { x: number; y: number }>()
  let x = right + PLACE_GAP * 2
  let y = topY
  let columnWidth = 0

  for (const group of top.filter((node) => fresh.has(node.id))) {
    const size = sizeOf(group, cardSize)

    if (y > topY && y + size.height > topY + columnHeight) {
      x += columnWidth + PLACE_GAP
      y = topY
      columnWidth = 0
    }

    placed.set(group.id, { x, y })
    y += size.height + PLACE_GAP
    columnWidth = Math.max(columnWidth, size.width)
  }

  return nodes.map((node) => (placed.has(node.id) ? { ...node, position: placed.get(node.id)! } : node))
}

export function Canvas() {
  const reactFlow = useReactFlow<ViewNode, Edge>()
  const store = useStoreApi<ViewNode, Edge>()
  const still = useStore((state) => state.transform[2] < STILL_ZOOM)
  const quietZoom = useStore((state) => state.transform[2] < QUIET_ZOOM)
  const away = useAway()
  const [nodes, setNodes] = useAtom(nodesAtom)
  const [links, setLinks] = useAtom(linksAtom)
  const [github, setGithub] = useState<GithubSnapshot | null>(null)
  const [syncStatus, setSyncStatus] = useState<SyncStatus | null>(null)
  const [workspaces, setWorkspaces] = useState<Workspaces>({ active: 'default', workspaces: [{ name: 'default', label: 'Default' }] })
  const [clock, setClock] = useState(() => Date.now())
  const [ready, setReady] = useState(false)
  const [root, setRoot] = useState<string | null>(null)
  // How many levels of nesting show below the open group; zoom no longer changes it.
  const [detail, setDetail] = useState<Detail>(DEFAULT_DETAIL)
  const [hover, setHover] = useAtom(hoverAtom)
  const [pinned, setPinned] = useAtom(pinnedAtom)
  // A double-clicked card fills the view with what it waits on and leads to beside it.
  const [focusPick, setFocus] = useState<string | null>(null)
  // Where focus started, and whether it has since walked to another card or level.
  const focusEntry = useRef<FocusEntry | null>(null)
  const [editing, setEditing] = useState<string | null>(null)
  const [sidebar, setSidebar] = useState(() => readFlag(SIDEBAR_KEY, true))
  const [appearance, setAppearance] = useState(readAppearance)
  const setSkin = useSetAtom(skinAtom, { store: skinStore })
  const systemMotion = useSystemMotion()
  const [keybindings, setKeybindings] = useState(readKeybindings)
  /** The settings section on show, or null while settings are closed. */
  const [settings, setSettings] = useState<SettingsSection | null>(null)
  const cardSize = useAtomValue(cardSizeAtom, { store: skinStore })
  const cardSizeRef = useRef(cardSize)

  useLayoutEffect(() => {
    cardSizeRef.current = cardSize
  }, [cardSize])

  const [debug, setDebug] = useState(() => readFlag(DEBUG_KEY, false))
  const companion = useCompanionTargets()
  const [motion, setMotion] = useState(readMotion)
  const [menu, setMenu] = useState<Menu | null>(null)
  const [tool, setTool] = useState<Tool>('select')
  /** The text the palette opened with, or null while it's closed. */
  const [paletteQuery, setPaletteQuery] = useState<string | null>(null)
  const paletteOpen = paletteQuery !== null
  /** Commands and places the palette used lately, newest first, for the workspace named. Null until that workspace's copy is read. */
  const [recents, setRecents] = useState<{ workspace: string; list: Recent[] } | null>(null)
  const [stickers, setStickers] = useState<Sticker[]>([])
  const [loadout, setLoadout] = useState<Loadout>(() => loadoutOf())
  const [chosenSticker, setSticker] = useState<string | null>(null)
  const sticker = chosenSticker ?? loadout.find((sticker) => sticker !== null) ?? FALLBACK_STICKER
  const [wheel, setWheel] = useState<{ x: number; y: number; held: boolean } | null>(null)
  const [fresh, setFresh] = useState<ReadonlySet<string>>(new Set())
  const canvasRef = useRef<HTMLDivElement>(null)
  const latest = useRef<Saved>({ nodes, links, stickers, stickerLoadout: loadout })
  const tweenSequence = useRef(0)
  const fitZoom = useRef(new Map<string, number>())
  const fitting = useRef(false)
  const fitSequence = useRef(0)
  const skipNextFit = useRef(false)

  // ---- Navigation history ----
  const trail = useRef<Trail<FocusEntry>>(emptyTrail())
  const [trailSize, setTrailSize] = useState({ back: 0, forward: 0 })
  // Read through a ref so the callbacks below, which cards get through the actions context, stay stable.
  const shownPlace = useRef({ root, focus: focusPick })

  useLayoutEffect(() => {
    shownPlace.current = { root, focus: focusPick }
  }, [root, focusPick])

  const updateTrail = useCallback((next: Trail<FocusEntry>) => {
    trail.current = next
    setTrailSize({ back: next.back.length, forward: next.forward.length })
  }, [])

  const here = useCallback(
    (viewport = reactFlow.getViewport()): Place<FocusEntry> => ({
      ...shownPlace.current,
      selected: latest.current.nodes.filter((node) => node.selected).map((node) => node.id),
      viewport,
      extra: focusEntry.current ? { ...focusEntry.current } : undefined,
    }),
    [reactFlow],
  )

  /** Records where the canvas is before it navigates somewhere else. */
  const remember = useCallback((viewport?: Viewport) => updateTrail(leave(trail.current, here(viewport))), [here, updateTrail])

  const openRoot = useCallback(
    (target: string | null) => {
      if (target !== shownPlace.current.root || shownPlace.current.focus) remember()

      setFocus(null)
      focusEntry.current = null
      skipNextFit.current = false
      setRoot(target)
    },
    [remember],
  )

  // ---- Undo ----

  /** Shows an undone or redone document, keeping the selection and every node the step left alone. */
  const showStep = useCallback(
    (doc: Saved): Saved => {
      const shown = byId(latest.current.nodes)
      const nodes = normalize(doc.nodes).map((node) => {
        const previous = shown.get(node.id)

        if (!previous) return node

        return JSON.stringify(slim([previous])) === JSON.stringify(slim([node])) ? previous : { ...node, selected: previous.selected }
      })
      const ids = new Set(nodes.map((node) => node.id))
      const next = { nodes, links: doc.links, stickers: doc.stickers ?? [], stickerLoadout: loadoutOf(doc.stickerLoadout) }

      latest.current = next
      setNodes(nodes)
      setLinks(next.links)
      setStickers(next.stickers)
      setLoadout(next.stickerLoadout)

      // The open group can go with the step, such as when undoing its creation from inside it.
      if (root && !ids.has(root)) openRoot(ancestors(root, shown).find((id) => ids.has(id)) ?? null)

      return next
    },
    [root, openRoot, setLinks, setNodes],
  )
  const getDoc = useCallback(() => latest.current, [])
  const {
    undo,
    redo,
    canUndo,
    canRedo,
    rebase: rebaseHistory,
    reset: resetHistory,
  } = useUndo({ doc: { nodes, links, stickers, stickerLoadout: loadout }, busy: nodes.some((node) => node.dragging), getDoc, apply: showStep })

  // A group's selection waits until a second click, which would open it, can no longer arrive.
  const plainClick = useRef<'defer' | null>(null)
  const clickTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)
  const clickQueue = useRef<(() => void)[]>([])
  const afterClick = useCallback((run: () => void) => {
    clickQueue.current.push(run)
    clearTimeout(clickTimer.current)
    clickTimer.current = setTimeout(() => {
      const queued = clickQueue.current

      clickQueue.current = []

      for (const callback of queued) callback()
    }, DOUBLE_CLICK_MS)
  }, [])
  const cancelClick = useCallback(() => {
    clearTimeout(clickTimer.current)
    clickQueue.current = []
  }, [])

  useEffect(() => cancelClick, [cancelClick])

  // Also runs when the computer's reduced motion setting changes, which Orion follows until a level is picked.
  useEffect(() => applyAppearance(appearance), [appearance, systemMotion])

  // The skin atom is read when its module loads, which is before saved settings arrive.
  useEffect(() => setSkin(appearance.skin), [appearance.skin, setSkin])

  // Runs before React Flow's own click handling, which selects the node as it goes.
  const claimNodeClick = (event: React.MouseEvent) => {
    const target = event.target as HTMLElement
    const node = target.closest('.react-flow__node')

    if (event.metaKey || event.shiftKey || event.ctrlKey || !node || target.closest('button, input, textarea, select')) return

    plainClick.current = node.classList.contains('react-flow__node-cluster') ? 'defer' : null
    setTimeout(() => (plainClick.current = null))
  }

  useLayoutEffect(() => {
    latest.current = { nodes, links, stickers, stickerLoadout: loadout }
  }, [nodes, links, stickers, loadout])
  // Folded groups hold one on-screen size through --inv, set outside React so zooming doesn't re-render them.
  useEffect(() => {
    let shown = 0

    const apply = (zoom: number) => {
      if (zoom === shown) return

      shown = zoom
      canvasRef.current?.style.setProperty('--inv', String(1 / zoom))
    }

    apply(store.getState().transform[2])

    return store.subscribe((state) => apply(state.transform[2]))
  }, [store])

  // ---- Persistence ----
  const source = useRef<'file' | 'browser'>('file')
  const revision = useRef<number | null>(null)
  const savedPrint = useRef('')
  const base = useRef<Saved>({ nodes: [], links: [] })
  const [mergeNotice, setMergeNotice] = useState<number | null>(null)
  const [imageError, setImageError] = useState<string | null>(null)
  const noticeTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  // Saves and reloads run one at a time so a reload never lands on a half-finished save.
  const queue = useRef<Promise<void>>(Promise.resolve())
  const workspace = useRef('default')
  const workspaceEpoch = useRef(0)
  const pendingWorkspaceFit = useRef<number | null>(null)
  const [savedView, setSavedView] = useState<Viewport | null>(null)
  // The workspace the canvas is showing, so moves while switching aren't remembered for the next one.
  const viewFor = useRef<string | null>(null)
  const displayedCardSize = useRef(cardSize)

  useLayoutEffect(() => {
    const previousSize = displayedCardSize.current

    if (previousSize.width === cardSize.width && previousSize.height === cardSize.height) return

    tweenSequence.current++
    const currentStored = compactDoc({ ...latest.current, nodes: toStored(latest.current.nodes, previousSize) })
    const wasSaved = fingerprint(currentStored) === savedPrint.current
    const mapped = toDisplayed(toStored(latest.current.nodes, previousSize), cardSize)
    const box = canvasRef.current?.getBoundingClientRect()

    if (box?.width && box.height) {
      const previousViewport = reactFlow.getViewport()
      const nodeMap = byId(mapped)
      const focusedNode = focusPick ? nodeMap.get(focusPick) : undefined
      const openGroup = root ? nodeMap.get(root) : undefined
      const groupViewport = openGroup && isCluster(openGroup) ? groupFitViewport(openGroup, nodeMap, box, cardSize) : undefined

      if (root && groupViewport) fitZoom.current.set(root, groupViewport.zoom)

      if (focusEntry.current)
        focusEntry.current.viewport = groupViewport ?? mapViewportForCardSize(focusEntry.current.viewport, box, previousSize, cardSize)

      const viewport =
        focusedNode && isTask(focusedNode)
          ? focusViewport(focusedNode, nodeMap, box, cardSize)
          : (groupViewport ?? mapViewportForCardSize(previousViewport, box, previousSize, cardSize))

      fitSequence.current++
      fitting.current = false
      void reactFlow.setViewport(viewport)
    }

    latest.current = { ...latest.current, nodes: mapped }
    displayedCardSize.current = cardSize
    setNodes(mapped)

    if (wasSaved) {
      base.current = compactDoc({ ...latest.current, nodes: toStored(mapped, cardSize) })
      savedPrint.current = fingerprint(base.current)
    }
  }, [cardSize, setNodes, reactFlow, focusPick, root])

  const adopt = useCallback(
    (doc: Remote, serverDoc: Remote = doc, preserveSelection = true): Saved => {
      const next = toDisplayed(normalize(doc.nodes), cardSizeRef.current)
      const server = compactDoc({
        nodes: normalize(serverDoc.nodes),
        links: serverDoc.links,
        stickers: serverDoc.stickers,
        stickerLoadout: serverDoc.stickerLoadout,
      })

      revision.current = doc.revision
      base.current = server
      savedPrint.current = fingerprint(server)
      const stickerLoadout = loadoutOf(doc.stickerLoadout)
      const adopted = { nodes: next, links: doc.links, stickers: doc.stickers ?? [], stickerLoadout }

      rebaseHistory(adopted)
      latest.current = adopted
      setNodes((currentNodes) => {
        const picked = new Set(preserveSelection ? currentNodes.filter((node) => node.selected).map((node) => node.id) : [])

        return picked.size ? next.map((node) => (picked.has(node.id) ? { ...node, selected: true } : node)) : next
      })
      setLinks(doc.links)
      setStickers(doc.stickers ?? [])
      setLoadout(stickerLoadout)
      setGithub(doc.github ?? null)

      return adopted
    },
    [rebaseHistory, setLinks, setNodes],
  )

  useEffect(
    () => () => {
      if (noticeTimer.current) clearTimeout(noticeTimer.current)
    },
    [],
  )

  const reload = useCallback(
    async (name: string, epoch: number) => {
      if (epoch !== workspaceEpoch.current) return

      const doc = await fetchRemote(name)

      if (epoch !== workspaceEpoch.current) return

      if (!doc || doc.revision === revision.current) return

      const local = compactDoc({ ...latest.current, nodes: toStored(latest.current.nodes, cardSizeRef.current) })

      if (fingerprint(local) === savedPrint.current) adopt(doc)
      else {
        const merged = mergeDocs(base.current, local, compactDoc({ ...doc, nodes: normalize(doc.nodes) }))

        adopt({ ...doc, ...merged }, doc)
      }
    },
    [adopt],
  )

  const loadWorkspace = useCallback(
    async (name: string, epoch: number, switched = false) => {
      const loaded = await load(name)

      if (epoch !== workspaceEpoch.current) return

      if (loaded.source === 'file') {
        source.current = 'file'
        resetHistory(adopt(loaded.doc, loaded.doc, !switched))
      } else {
        source.current = loaded.source === 'missing' ? 'file' : 'browser'
        const isDefault = name === 'default'
        const kept = isDefault ? (loaded.source === 'browser' ? loaded.saved : readBrowser()) : null
        const start = kept ? { nodes: toDisplayed(normalize(kept.nodes), cardSizeRef.current), links: kept.links } : { nodes: [], links: [] }
        const initialStickers = kept?.stickers ?? []
        const initialLoadout = loadoutOf(kept?.stickerLoadout)

        if (epoch !== workspaceEpoch.current) return

        revision.current = null
        savedPrint.current = ''
        base.current = { nodes: [], links: [] }
        latest.current = { ...start, stickers: initialStickers, stickerLoadout: initialLoadout }
        resetHistory(latest.current)
        setNodes(start.nodes)
        setLinks(start.links)
        setStickers(initialStickers)
        setLoadout(initialLoadout)
        setGithub(null)
      }

      const view = readViewport(workspace.current)

      setDetail(readDetail(workspace.current))

      if (view) pendingWorkspaceFit.current = null

      setSavedView(view)
      viewFor.current = workspace.current
      setReady(true)
    },
    [adopt, resetHistory, setLinks, setNodes],
  )

  useEffect(() => {
    let cancelled = false
    const epoch = workspaceEpoch.current

    void getWorkspaces().then(async (list) => {
      if (cancelled || epoch !== workspaceEpoch.current) return

      workspace.current = list.active
      setWorkspaces(list)
      await loadWorkspace(list.active, epoch)
    })

    return () => {
      cancelled = true
    }
  }, [loadWorkspace])

  useEffect(
    () =>
      onRemoteChange((next) => {
        const name = workspace.current
        const epoch = workspaceEpoch.current

        queue.current = queue.current.then(() => (epoch === workspaceEpoch.current && next !== revision.current ? reload(name, epoch) : undefined))
      }),
    [reload],
  )

  useEffect(() => {
    void getSyncStatus().then((status) => status && setSyncStatus(status))
    const off = onSyncStatus(setSyncStatus)
    const onFocus = () => void requestSync().then((status) => status && setSyncStatus(status))

    const onVisible = () => {
      if (document.visibilityState === 'visible') onFocus()
    }

    window.addEventListener('focus', onFocus)
    document.addEventListener('visibilitychange', onVisible)
    const timer = setInterval(() => setClock(Date.now()), 60_000)

    return () => {
      off()
      window.removeEventListener('focus', onFocus)
      document.removeEventListener('visibilitychange', onVisible)
      clearInterval(timer)
    }
  }, [])

  useEffect(() => {
    if (!ready) return

    const saveTimer = setTimeout(() => {
      // Stickers on cards or groups that are gone go with them.
      const ids = new Set(nodes.map((node) => node.id))
      const snapshot = { nodes, links, stickers: stickers.filter((sticker) => !sticker.on || ids.has(sticker.on)), stickerLoadout: loadout }
      const print = fingerprint({ ...snapshot, nodes: toStored(nodes, cardSize) })
      const epoch = workspaceEpoch.current
      const name = workspace.current

      queue.current = queue.current.then(async () => {
        if (epoch !== workspaceEpoch.current) return

        if (print === savedPrint.current) return

        let pending: Saved = snapshot

        for (let attempt = 0; attempt <= 2; attempt++) {
          const result = await save(source.current, revision.current, pending, name, cardSize)

          if (epoch !== workspaceEpoch.current) return

          if (result.ok) {
            revision.current = result.revision
            base.current = compactDoc({ ...pending, nodes: toStored(pending.nodes, cardSize) })
            savedPrint.current = fingerprint({ ...pending, nodes: toStored(pending.nodes, cardSize) })

            return
          }

          if (!result.conflict || attempt === 2) break

          const remote = await fetchRemote(name)

          if (epoch !== workspaceEpoch.current) return

          if (!remote) break

          const merged = mergeDocs(
            base.current,
            compactDoc({ ...latest.current, nodes: toStored(latest.current.nodes, cardSize) }),
            compactDoc({ ...remote, nodes: normalize(remote.nodes) }),
          )

          pending = adopt({ ...remote, ...merged }, remote)

          if (merged.conflicts.length) {
            setMergeNotice(merged.conflicts.length)

            if (noticeTimer.current) clearTimeout(noticeTimer.current)

            noticeTimer.current = setTimeout(() => setMergeNotice(null), 4500)
          }
        }

        await reload(name, epoch)
      })
    }, 400)

    return () => clearTimeout(saveTimer)
  }, [nodes, links, stickers, loadout, ready, reload, adopt, cardSize])

  const pendingLayoutEpoch = useRef<number | null>(null)

  useEffect(() => {
    const epoch = workspaceEpoch.current

    if (!ready || pendingLayoutEpoch.current === epoch) return

    const marked = nodes.filter((node) => isCluster(node) && node.data.layout)

    if (!marked.length) return

    const pending = marked.filter((node) => isCluster(node) && node.data.layout === 'pending')

    pendingLayoutEpoch.current = epoch

    void (async () => {
      let next = nodes

      try {
        for (const group of marked) {
          try {
            next = await reflow(next, links, group.id, cardSize)
          } catch (error) {
            console.error('Could not lay out group', group.id, error)
          }
        }

        if (pending.length) next = placeBesideExisting(next, new Set(pending.map((group) => group.id)), cardSize)
      } catch (error) {
        console.error('Could not lay out canvas', error)
      } finally {
        if (epoch === workspaceEpoch.current) {
          const laidOut = next.map((node) => (isCluster(node) && node.data.layout ? { ...node, data: { ...node.data, layout: undefined } } : node))

          // Laying out groups another writer added finishes their write, so it isn't a step to undo.
          rebaseHistory({ ...latest.current, nodes: laidOut })
          setNodes(laidOut)
        }

        if (pendingLayoutEpoch.current === epoch) pendingLayoutEpoch.current = null
      }
    })()
  }, [nodes, links, ready, rebaseHistory, setNodes, cardSize])
  const changeWorkspace = useCallback(
    (name: string) => {
      if (name === workspace.current) return

      clearFocus(workspace.current)
      workspace.current = name
      viewFor.current = null
      const epoch = ++workspaceEpoch.current

      pendingWorkspaceFit.current = epoch
      setReady(false)
      setRecents(null)
      setRoot(null)
      setFocus(null)
      focusEntry.current = null
      updateTrail(emptyTrail())
      setPinned(null)
      setHover(null)
      setEditing(null)
      setMergeNotice(null)

      if (noticeTimer.current) clearTimeout(noticeTimer.current)

      queue.current = queue.current.then(async () => {
        const list = await getWorkspaces()

        if (epoch !== workspaceEpoch.current) return

        setWorkspaces(list)
        await loadWorkspace(name, epoch, true)
      })
    },
    [loadWorkspace, updateTrail, setHover, setPinned],
  )

  useEffect(() => onWorkspaceChange(changeWorkspace), [changeWorkspace])

  // Each workspace keeps its own recents in the data folder, read once its canvas is showing.
  useEffect(() => {
    if (!ready) return

    const name = workspace.current
    let cancelled = false

    // Without a read, recents stay off for this workspace rather than starting from an empty list.
    readFileSetting(recentsKey(name)).then(
      (value) => {
        if (!cancelled) setRecents({ workspace: name, list: readRecents(value) })
      },
      () => {},
    )

    return () => {
      cancelled = true
    }
  }, [ready])

  /** Moves a command or place to the top of the recents, forgetting cards and groups that are gone. */
  const rememberRecent = useCallback(
    (entry: Recent) => {
      if (!recents) return

      const ids = new Set(latest.current.nodes.map((node) => node.id))
      const list = addRecent(keepExistingNodes(recents.list, ids), entry)

      setRecents({ workspace: recents.workspace, list })
      saveFileSetting(recentsKey(recents.workspace), list)
    },
    [recents],
  )

  useEffect(() => onWorkspaceListChange((list) => setWorkspaces((current) => ({ ...current, workspaces: list.workspaces }))), [])

  useEffect(() => {
    if (!ready || pendingWorkspaceFit.current !== workspaceEpoch.current) return

    const epoch = workspaceEpoch.current
    const frame = requestAnimationFrame(() => {
      if (pendingWorkspaceFit.current !== epoch) return

      pendingWorkspaceFit.current = null

      if (nodes.length) void reactFlow.fitView({ padding: 0.08, duration: glide(450) })
      else void reactFlow.setViewport({ x: 0, y: 0, zoom: 1 }, { duration: glide(450) })
    })

    return () => cancelAnimationFrame(frame)
  }, [ready, nodes, reactFlow])

  const rememberView = useCallback((_: MouseEvent | TouchEvent | null, viewport: Viewport) => {
    canvasRef.current?.removeAttribute('data-moving')

    if (viewFor.current === workspace.current) writeViewport(workspace.current, viewport)
  }, [])
  // An attribute rather than a class, so re-renders mid-move don't clear it.
  const onMoveStart = useCallback(() => {
    if (motion.pauseWhileMoving) canvasRef.current?.setAttribute('data-moving', '')
  }, [motion.pauseWhileMoving])

  const switchWorkspace = async (name: string) => {
    const list = await setActiveWorkspace(name)

    setWorkspaces(list)
    changeWorkspace(name)
  }

  const newWorkspace = async (name: string, label: string) => {
    const list = await createWorkspace(name, label)

    setWorkspaces(list)
    await switchWorkspace(name)
  }

  /**
   * Fits the opened group, or everything at the top level. Bounds come from our own
   * data because nodes hidden since load have never been measured by React Flow.
   */
  const fitTo = useCallback(
    (target: string | null) => {
      const currentNodes = latest.current.nodes
      const nodeMap = byId(currentNodes)
      const items = target ? [nodeMap.get(target)].filter((node) => !!node) : currentNodes.filter((node) => !node.parentId)

      if (!items.length) return

      let x0 = Infinity
      let y0 = Infinity
      let x1 = -Infinity
      let y1 = -Infinity

      for (const node of items) {
        const position = absolutePosition(node, nodeMap)
        const size = sizeOf(node, cardSize)

        x0 = Math.min(x0, position.x)
        y0 = Math.min(y0, position.y)
        x1 = Math.max(x1, position.x + size.width)
        y1 = Math.max(y1, position.y + size.height)
      }

      const box = canvasRef.current?.getBoundingClientRect()

      if (!target || !box) {
        reactFlow.fitBounds({ x: x0, y: y0, width: x1 - x0, height: y1 - y0 }, { padding: 0.08, duration: glide(450) })

        return
      }

      // An opened group fills the view, with the connections outside it peeking in from the edges.
      const viewport = groupFitViewport(items[0], nodeMap, box, cardSize)

      fitZoom.current.set(target, viewport.zoom)
      fitting.current = true
      const sequence = ++fitSequence.current

      void reactFlow.setViewport(viewport, { duration: glide(450) }).then(() => {
        if (fitSequence.current === sequence) fitting.current = false
      })
    },
    [reactFlow, cardSize],
  )

  const selectOnly = useCallback(
    (id: string) =>
      setNodes((currentNodes) =>
        currentNodes.map((node) => (node.id === id ? { ...node, selected: true } : node.selected ? { ...node, selected: false } : node)),
      ),
    [setNodes],
  )

  const focusNode = useCallback(
    (id: string) => {
      const nodeMap = byId(latest.current.nodes)
      const node = nodeMap.get(id)

      if (!node) return

      selectOnly(id)
      const position = absolutePosition(node, nodeMap)
      const size = sizeOf(node, cardSize)

      reactFlow.setCenter(position.x + size.width / 2, position.y + size.height / 2, {
        zoom: Math.max(reactFlow.getZoom(), 0.9),
        duration: glide(450),
      })
    },
    [reactFlow, selectOnly, cardSize],
  )

  // Opening or closing a group fits it, unless a jump asked to land on one card.
  const fittedFor = useRef<string | null>(null)
  const pendingFocus = useRef<string | null>(null)

  useEffect(() => {
    if (fittedFor.current === root) return

    fittedFor.current = root
    const skipFit = skipNextFit.current

    skipNextFit.current = false

    if (skipFit) return

    const frame = pendingFocus.current

    pendingFocus.current = null

    if (frame) setTimeout(() => focusNode(frame), 30)
    else fitTo(root)
  }, [root, fitTo, focusNode])

  /** Opens the group a card lives in and lands on the card. */
  const jumpTo = useCallback(
    (id: string) => {
      const node = byId(latest.current.nodes).get(id)

      if (!node) return

      const target = node.parentId ?? null

      remember()
      setHover(null)

      if (target === root) {
        focusNode(id)
      } else {
        pendingFocus.current = id
        openRoot(target)
      }
    },
    [root, focusNode, openRoot, remember, setHover],
  )

  /** Moves nodes to new positions over a few frames so edges follow along. */
  const tweenTo = useCallback(
    (target: AppNode[]) => {
      if (motionReduced()) {
        setNodes(target)

        return
      }

      const from = byId(latest.current.nodes)
      const start = performance.now()
      const sequence = ++tweenSequence.current

      const step = (now: number) => {
        if (sequence !== tweenSequence.current) return

        const progress = ease(Math.min(1, (now - start) / 380))

        setNodes(
          target.map((node) => {
            const sourceNode = from.get(node.id)

            if (!sourceNode || sourceNode.parentId !== node.parentId || progress === 1) return node

            const lerp = (startValue: number, endValue: number) => startValue + (endValue - startValue) * progress

            return {
              ...node,
              position: { x: lerp(sourceNode.position.x, node.position.x), y: lerp(sourceNode.position.y, node.position.y) },
              ...(isCluster(node) && sourceNode.width && node.width
                ? { width: lerp(sourceNode.width, node.width), height: lerp(sourceNode.height ?? 0, node.height ?? 0) }
                : {}),
            }
          }),
        )

        if (progress < 1) requestAnimationFrame(step)
      }

      requestAnimationFrame(step)
    },
    [setNodes],
  )

  const map = useMemo(() => byId(nodes), [nodes])
  // Focus ends on its own if someone else removes the card.
  const focus = focusPick && map.has(focusPick) ? focusPick : null

  useInspecting()

  const inspecting = useAtomValue(inspectingAtom)

  const work = useAtomValue(workAtom)

  // Which groups read as single bodies at this level of detail, and which nodes that hides.
  const inView = useCallback((id: string) => !root || id === root || ancestors(id, map).includes(root), [root, map])

  const depthInView = (id: string) => {
    const chain = ancestors(id, map)

    return root ? chain.indexOf(root) : chain.length
  }

  const groupDepths = nodes.filter((node) => isCluster(node) && node.id !== root && inView(node.id)).map((node) => depthInView(node.id))
  const levels = detailLevels(groupDepths)
  const foldFrom = foldDepth(detail, levels)
  const small = nodes
    .filter((node) => isCluster(node) && node.id !== root && inView(node.id) && depthInView(node.id) >= foldFrom)
    .map((node) => node.id)
  const smallSet = new Set(small)
  const collapsedKey = small.filter((id) => !ancestors(id, map).some((ancestor) => smallSet.has(ancestor))).join(',')
  const collapsed = useMemo(() => new Set(collapsedKey ? collapsedKey.split(',') : []), [collapsedKey])
  const level = shownLevel(detail, levels)

  /** Shows one level less or more of the nesting below the open group, and remembers it for this workspace. */
  const changeDetail = useCallback(
    (direction: -1 | 1) => {
      const next = stepDetail(detail, levels, direction)

      setDetail(next)
      writeDetail(workspace.current, next)
    },
    [detail, levels],
  )

  const view = useMemo(() => {
    const representative = (id: string): string | null => {
      if (!inView(id)) return null

      const outer = ancestors(id, map)
        .reverse()
        .find((ancestor) => collapsed.has(ancestor))

      return outer ?? id
    }

    const hidden = new Set(nodes.filter((node) => representative(node.id) !== node.id).map((node) => node.id))

    return { rep: representative, hidden }
  }, [nodes, map, collapsed, inView])

  // With a group open, work outside it that links in or out is drawn along its sides.
  const ghosts = useMemo(() => {
    const ghostNodes: GhostNode[] = []
    const rootNode = root ? map.get(root) : undefined

    if (!rootNode) return ghostNodes

    const incoming: string[] = []
    const outgoing: string[] = []

    for (const link of links) {
      const source = inView(link.from)
      const target = inView(link.to)

      if (source && !target && !outgoing.includes(link.to)) outgoing.push(link.to)

      if (!source && target && !incoming.includes(link.from)) incoming.push(link.from)
    }

    const position = absolutePosition(rootNode, map)
    const size = sizeOf(rootNode, cardSize)
    const place = (ids: string[], side: 'in' | 'out') =>
      ids.forEach((id, i) => {
        const node = map.get(id)

        if (!node || !isTask(node)) return

        const parent = node.parentId ? map.get(node.parentId) : undefined

        ghostNodes.push({
          id: `ghost:${side}:${id}`,
          type: 'ghost',
          position: {
            x: side === 'in' ? position.x - GHOST_WIDTH - GHOST_GAP : position.x + size.width + GHOST_GAP,
            y: position.y + size.height / 2 + (i - (ids.length - 1) / 2) * (GHOST_HEIGHT + 18) - GHOST_HEIGHT / 2,
          },
          width: GHOST_WIDTH,
          height: GHOST_HEIGHT,
          // Ghosts are rebuilt every render, so declare their handles instead of waiting on a measure.
          handles: [
            side === 'in'
              ? { type: 'source', position: Position.Right, x: GHOST_WIDTH - 4, y: GHOST_HEIGHT / 2 - 4, width: 8, height: 8 }
              : { type: 'target', position: Position.Left, x: -4, y: GHOST_HEIGHT / 2 - 4, width: 8, height: 8 },
          ],
          selectable: false,
          draggable: false,
          connectable: false,
          zIndex: 5,
          data: {
            kind: 'ghost',
            taskId: id,
            label: node.data.label || 'Note',
            where: parent ? (parent.data as ClusterData).label : 'loose work',
            status: work.status.get(id) ?? 'ready',
            side,
          },
        })
      })

    place(incoming, 'in')
    place(outgoing, 'out')

    return ghostNodes
  }, [root, map, links, inView, work, cardSize])

  // React Flow redraws a node whenever its object changes, so unchanged nodes keep last render's object.
  const [shownNodes] = useState(() => new WeakMap<AppNode, AppNode>())
  const viewNodes = useMemo<ViewNode[]>(
    () => [
      ...nodes.map((node) => {
        const hidden = view.hidden.has(node.id)
        const className = [node.className, focus ? (node.id === focus ? 'is-focused' : 'is-unfocused') : ''].filter(Boolean).join(' ') || undefined
        const shown = shownNodes.get(node)

        if (shown && shown.hidden === hidden && shown.className === className) return shown

        const next = { ...node, hidden, className }

        shownNodes.set(node, next)

        return next
      }),
      ...(focus ? ghosts.map((group) => ({ ...group, className: 'is-unfocused' })) : ghosts),
    ],
    [nodes, view, ghosts, focus, shownNodes],
  )

  const trace = useAtomValue(traceAtom)

  const selectedKey = nodes
    .filter((node) => node.selected)
    .map((node) => node.id)
    .join(',')
  /** Related links never block, so they stay faint except around the cards being looked at. */
  const relatedFocus = useMemo(() => new Set([pinned, hover, ...selectedKey.split(',')].filter(Boolean)), [pinned, hover, selectedKey])

  /** Where a link is drawn: the nodes standing in for its ends, ghosts for ends outside the open group, or null when it isn't drawn. */
  const drawnEnds = useCallback(
    (link: Link) => {
      let source = view.rep(link.from)
      let target = view.rep(link.to)

      if (root && !source && target) source = `ghost:in:${link.from}`

      if (root && source && !target && !source.startsWith('ghost:')) target = `ghost:out:${link.to}`

      if (!source || !target || source === target) return null

      return { source, target }
    },
    [view, root],
  )

  const [drawnEdges] = useState(() => new Map<string, { edge: Edge; print: string }>())
  const edges = useMemo(() => {
    const resultEdges: Edge[] = []
    const marker = (flow: Flow) => ({ type: MarkerType.ArrowClosed, width: 14, height: 14, color: `var(${EDGE_COLOR[flow]})` })
    const aggregates = new Map<string, { a: string; b: string; count: number; flow: Flow }>()

    for (const link of links) {
      const ends = drawnEnds(link)

      if (!ends) continue

      const { source, target } = ends
      const flow = work.flow.get(link.from) ?? 'live'
      const direct = (source === link.from || source.startsWith('ghost:')) && (target === link.to || target.startsWith('ghost:'))

      if (direct) {
        let className = link.kind === 'related' ? 'e-rel' : `e-${flow}`

        if (link.kind === 'related' && !relatedFocus.has(link.from) && !relatedFocus.has(link.to)) className += ' e-rel-quiet'

        if (trace) {
          const sourceRole = trace.get(link.from)
          const targetRole = trace.get(link.to)
          const up = link.kind === 'blocks' && sourceRole === 'up' && (targetRole === 'up' || targetRole === 'self')
          const down = link.kind === 'blocks' && (sourceRole === 'down' || sourceRole === 'self') && targetRole === 'down'
          const near = link.kind === 'related' && (sourceRole === 'self' || targetRole === 'self')

          className += up ? ' tr-e-up' : down ? ' tr-e-down' : near ? ' tr-e-rel' : ' tr-e-dim'
        }

        resultEdges.push({
          id: link.id,
          source: source,
          target: target,
          className: className,
          markerEnd: link.kind === 'blocks' ? marker(flow) : undefined,
        })
      } else if (link.kind === 'blocks') {
        const key = source + '>' + target
        const aggregate = aggregates.get(key) ?? { a: source, b: target, count: 0, flow: 'held' }

        aggregate.count++

        // A bundle moves if any of its links do.
        if (flow === 'live') aggregate.flow = 'live'

        aggregates.set(key, aggregate)
      }
    }

    for (const [key, aggregate] of aggregates) {
      resultEdges.push({
        id: 'agg:' + key,
        source: aggregate.a,
        target: aggregate.b,
        className: `e-agg e-${aggregate.flow}`,
        selectable: false,
        label: aggregate.count > 1 ? `${aggregate.count} links` : undefined,
        markerEnd: marker(aggregate.flow),
        style: { strokeWidth: Math.min(6, 1.5 + aggregate.count * 0.8) },
      })
    }

    return keepDrawn(drawnEdges, resultEdges)
  }, [links, drawnEnds, work, trace, relatedFocus, drawnEdges])

  // ---- Attention: hold ⌘ to see what needs you ----
  const [attending, setAttending] = useState(false)
  const pointer = useRef<{ x: number; y: number } | null>(null)
  const [cursor, setCursor] = useState<{ x: number; y: number } | null>(null)
  const [canvasSize, setCanvasSize] = useState({ width: 0, height: 0 })

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | undefined

    const stop = () => {
      clearTimeout(timer)
      setAttending(false)
    }

    // A short delay keeps ⌥ shortcuts from flashing the overlay.
    const down = (event: KeyboardEvent) => {
      if (event.key !== 'Alt') return stop()

      if (event.repeat) return

      timer = setTimeout(() => {
        const rectangle = canvasRef.current?.getBoundingClientRect()

        if (rectangle) setCanvasSize({ width: rectangle.width, height: rectangle.height })

        setCursor(pointer.current ?? (rectangle ? { x: rectangle.width / 2, y: rectangle.height / 2 } : null))
        setAttending(true)
      }, ATTEND_DELAY_MS)
    }

    const up = (event: KeyboardEvent) => event.key === 'Alt' && stop()

    window.addEventListener('keydown', down)
    window.addEventListener('keyup', up)
    window.addEventListener('blur', stop)
    window.addEventListener('pointerdown', stop)

    return () => {
      clearTimeout(timer)
      window.removeEventListener('keydown', down)
      window.removeEventListener('keyup', up)
      window.removeEventListener('blur', stop)
      window.removeEventListener('pointerdown', stop)
    }
  }, [])

  // ---- Pan: hold ⌘ to move cards and groups, as in Select ----
  const [commandHeld, setCommandHeld] = useState(false)

  useEffect(() => {
    if (tool !== 'hand') return

    const down = (event: KeyboardEvent) => event.key === 'Meta' && setCommandHeld(true)
    const up = (event: KeyboardEvent) => event.key === 'Meta' && setCommandHeld(false)
    const stop = () => setCommandHeld(false)

    window.addEventListener('keydown', down)
    window.addEventListener('keyup', up)
    window.addEventListener('blur', stop)

    return () => {
      window.removeEventListener('keydown', down)
      window.removeEventListener('keyup', up)
      window.removeEventListener('blur', stop)
      stop()
    }
  }, [tool])

  // ---- Selection box ----
  const [marquee, setMarquee] = useState<{ x: number; y: number; width: number; height: number } | null>(null)

  /**
   * Drags a selection box from empty canvas. Anything it touches is selected, but an open
   * group needs to be fully inside, since you drag across its body to reach what's in it.
   * ⇧ or ⌘ adds to the selection, and ⌘ draws the box in Pan too.
   */
  const startMarquee = (event: React.PointerEvent) => {
    const target = event.target as HTMLElement
    const box = canvasRef.current?.getBoundingClientRect()

    if (focus || event.button !== 0 || !box || !target.classList.contains('react-flow__pane')) return

    // In Select, a draggable pane means Space is held to pan.
    if (tool === 'select' ? target.classList.contains('draggable') : !(tool === 'hand' && event.metaKey)) return

    // Keeps the drag from also panning in Pan.
    event.preventDefault()
    const start = reactFlow.screenToFlowPosition({ x: event.clientX, y: event.clientY })
    const base = event.shiftKey || event.metaKey ? nodes.filter((node) => node.selected).map((node) => node.id) : []
    const things = nodes
      .filter((node) => node.id !== root && !view.hidden.has(node.id) && inView(node.id))
      .map((node) => {
        const position = absolutePosition(node, map)
        const size = sizeOf(node, cardSize)

        return {
          id: node.id,
          x0: position.x,
          y0: position.y,
          x1: position.x + size.width,
          y1: position.y + size.height,
          whole: isCluster(node) && !collapsed.has(node.id),
        }
      })
    let moved = false
    let last = ''

    const move = (moveEvent: PointerEvent) => {
      if (!moved && Math.hypot(moveEvent.clientX - event.clientX, moveEvent.clientY - event.clientY) < 3) return

      moved = true
      const end = reactFlow.screenToFlowPosition({ x: moveEvent.clientX, y: moveEvent.clientY })
      const [x0, x1] = [Math.min(start.x, end.x), Math.max(start.x, end.x)]
      const [y0, y1] = [Math.min(start.y, end.y), Math.max(start.y, end.y)]
      const from = reactFlow.flowToScreenPosition(start)

      setMarquee({
        x: Math.min(from.x, moveEvent.clientX) - box.left,
        y: Math.min(from.y, moveEvent.clientY) - box.top,
        width: Math.abs(moveEvent.clientX - from.x),
        height: Math.abs(moveEvent.clientY - from.y),
      })

      const covered = (target: (typeof things)[number]) => {
        const width = Math.min(target.x1, x1) - Math.max(target.x0, x0)
        const height = Math.min(target.y1, y1) - Math.max(target.y0, y0)
        const need = target.whole ? 1 : MARQUEE_REACH

        return width >= (target.x1 - target.x0) * need - 0.5 && height >= (target.y1 - target.y0) * need - 0.5
      }

      const hit = things.filter(covered).map((target) => target.id)
      const key = hit.join(',')

      if (key === last) return

      last = key
      const want = new Set([...base, ...hit])

      setNodes((currentNodes) =>
        currentNodes.map((node) => (!!node.selected === want.has(node.id) ? node : { ...node, selected: want.has(node.id) })),
      )
    }

    const end = () => {
      window.removeEventListener('pointermove', move)
      window.removeEventListener('pointerup', end)
      window.removeEventListener('pointercancel', end)
      setMarquee(null)

      if (!moved) return

      // The click that ends a drag would otherwise clear the selection.
      const swallow = (event: MouseEvent) => event.stopPropagation()

      window.addEventListener('click', swallow, { capture: true, once: true })
      setTimeout(() => window.removeEventListener('click', swallow, { capture: true }), 0)
    }

    window.addEventListener('pointermove', move)
    window.addEventListener('pointerup', end)
    window.addEventListener('pointercancel', end)
  }

  const trackPointer = (event: React.PointerEvent) => {
    const rectangle = canvasRef.current?.getBoundingClientRect()

    if (!rectangle) return

    pointer.current = { x: event.clientX - rectangle.left, y: event.clientY - rectangle.top }

    if (attending) setCursor(pointer.current)
  }

  const needs = useMemo(() => needsAttention(nodes, work.status), [nodes, work.status])

  // Work that needs you, gathered onto whatever shows it: the card, or the folded group around it.
  const attention = useMemo(() => {
    if (!attending) return null

    const marks = new Map<string, AttentionMark>()
    let elsewhere = 0

    for (const id of needs) {
      const shown = view.rep(id)

      if (!shown) {
        elsewhere++
        continue
      }

      const nodeMap = marks.get(shown) ?? { ids: [] }

      nodeMap.ids.push(id)
      marks.set(shown, nodeMap)
    }

    return { marks, count: needs.length - elsewhere, elsewhere }
  }, [attending, needs, view])

  const transform = useStore((state) => (attending ? state.transform : null))
  // The focus view tracks the viewport only while open, so zooming elsewhere doesn't re-render the canvas.
  const focusTransform = useStore((state) => (focus ? state.transform : null))
  const attentionTargets = useMemo<AttentionTarget[]>(() => {
    if (!attention || !transform) return []

    const [panX, panY, zoom] = transform
    const targets: AttentionTarget[] = []

    for (const [id, nodeMap] of attention.marks) {
      const node = map.get(id)

      if (!node) continue

      const position = absolutePosition(node, map)
      const size = sizeOf(node, cardSize)

      targets.push({
        id,
        jump: nodeMap.ids[0],
        count: nodeMap.ids.length,
        label: nodeMap.ids.length === 1 ? (map.get(nodeMap.ids[0])?.data.label ?? '') : node.data.label,
        rect: { x: position.x * zoom + panX, y: position.y * zoom + panY, width: size.width * zoom, height: size.height * zoom },
      })
    }

    return targets
  }, [attention, map, transform, cardSize])

  const setCollapsedShown = useSetAtom(collapsedAtom)
  const setAttentionShown = useSetAtom(attentionAtom)
  const setFocusedShown = useSetAtom(focusedAtom)

  // Before paint, so cards that read these never show a stale frame.
  useLayoutEffect(() => {
    setCollapsedShown(collapsed)
    setAttentionShown(attention?.marks ?? null)
    setFocusedShown(focus !== null)
  }, [collapsed, attention, focus, setCollapsedShown, setAttentionShown, setFocusedShown])

  const getCurrentNodes = useCallback(() => latest.current.nodes, [])
  const { snapChanges, onDragStart, onDrag, onDragStop, guides } = useNodeSnapping({ nodes, getCurrentNodes, setNodes, tweenTo, cardSize })
  const onNodesChange = useCallback(
    (changes: NodeChange<ViewNode>[]) => {
      let own = changes.filter((change) => !('id' in change) || !change.id.startsWith('ghost:')) as NodeChange<AppNode>[]

      if (plainClick.current) {
        const picks = own.filter((change) => change.type === 'select')

        own = own.filter((change) => change.type !== 'select')

        if (picks.length) afterClick(() => setNodes((currentNodes) => applyNodeChanges(picks, currentNodes)))
      }

      if (own.length) {
        const snapChangedNodes = snapChanges(own)

        setNodes((currentNodes) => snapChangedNodes(applyNodeChanges(own, currentNodes)))
      }
    },
    [afterClick, setNodes, snapChanges],
  )

  // ---- Focus on one card ----

  const focusOn = useCallback(
    (id: string) => {
      const nodeMap = byId(latest.current.nodes)
      const node = nodeMap.get(id)
      const box = canvasRef.current?.getBoundingClientRect()

      if (!node || !isTask(node) || !box) return

      remember()

      if (!focus || !focusEntry.current) focusEntry.current = { viewport: reactFlow.getViewport(), moved: false }
      else if (id !== focus) focusEntry.current.moved = true

      // Work outside the open level opens its own group underneath, so leaving focus lands there.
      if (!inView(id)) {
        const parent = node.parentId ? nodeMap.get(node.parentId) : undefined

        if (parent) fitZoom.current.set(parent.id, groupFitViewport(parent, nodeMap, box, cardSize).zoom)

        skipNextFit.current = true
        setRoot(parent?.id ?? null)
        focusEntry.current.moved = true
      }

      setHover(null)
      setPinned(null)
      setNodes((currentNodes) =>
        currentNodes.some((node) => node.selected) ? currentNodes.map((node) => (node.selected ? { ...node, selected: false } : node)) : currentNodes,
      )
      setFocus(id)
      void reactFlow.setViewport(focusViewport(node, nodeMap, box, cardSize), focusMove())
    },
    [reactFlow, focus, inView, remember, setHover, setNodes, setPinned, cardSize],
  )

  const exitFocus = useCallback(() => {
    const entry = focusEntry.current
    const nodeMap = byId(latest.current.nodes)
    const node = focus ? nodeMap.get(focus) : undefined

    remember()
    setFocus(null)
    focusEntry.current = null

    if (!entry) return

    if (!entry.moved || !node) {
      void reactFlow.setViewport(entry.viewport, focusMove())

      return
    }

    const position = absolutePosition(node, nodeMap)
    const size = sizeOf(node, cardSize)
    const zoom = (root ? fitZoom.current.get(root) : undefined) ?? entry.viewport.zoom

    void reactFlow.setCenter(position.x + size.width / 2, position.y + size.height / 2, { zoom, ...focusMove() })
  }, [focus, root, reactFlow, remember, cardSize])

  /** Puts the canvas back at a place from its history. */
  const goTo = useCallback(
    (place: Place<FocusEntry>) => {
      const nodeMap = byId(latest.current.nodes)
      const group = place.root ? nodeMap.get(place.root) : undefined
      const box = canvasRef.current?.getBoundingClientRect()
      const picked = new Set(place.selected)

      pendingFocus.current = null
      setHover(null)
      setPinned(null)

      // Zooming out of a group measures from its fitted zoom, which a group reopened from history may not have yet.
      if (group && box && !fitZoom.current.has(group.id)) fitZoom.current.set(group.id, groupFitViewport(group, nodeMap, box, cardSize).zoom)

      if (place.root !== root) {
        skipNextFit.current = true
        setRoot(place.root)
      }

      setFocus(place.focus)
      focusEntry.current = place.focus && place.extra ? { ...place.extra } : null
      setNodes((currentNodes) =>
        currentNodes.map((node) => (!!node.selected === picked.has(node.id) ? node : { ...node, selected: picked.has(node.id) })),
      )
      void reactFlow.setViewport(place.viewport, place.focus || focus ? focusMove() : { duration: glide(450) })
    },
    [root, focus, reactFlow, setHover, setNodes, setPinned, cardSize],
  )

  const travelTo = useCallback(
    (direction: 'back' | 'forward') => {
      const nodeMap = byId(latest.current.nodes)

      const exists = (place: Place<FocusEntry>) => {
        const group = place.root ? nodeMap.get(place.root) : undefined
        const card = place.focus ? nodeMap.get(place.focus) : undefined

        return (!place.root || (!!group && isCluster(group))) && (!place.focus || (!!card && isTask(card)))
      }

      const result = travel(trail.current, here(), direction, exists)

      if (!result) return

      updateTrail(result.trail)
      goTo(result.place)
    },
    [here, goTo, updateTrail],
  )

  useEffect(() => {
    const isSide = (event: MouseEvent) => event.button === 3 || event.button === 4

    // Handled on release, and the press is swallowed too, so the browser doesn't navigate the page.
    const press = (event: MouseEvent) => isSide(event) && event.preventDefault()

    const release = (event: MouseEvent) => {
      if (!isSide(event)) return

      event.preventDefault()
      travelTo(event.button === 3 ? 'back' : 'forward')
    }

    const fromShell = (event: Event) => {
      const direction = (event as CustomEvent<unknown>).detail

      if (direction === 'back' || direction === 'forward') travelTo(direction)
    }

    window.addEventListener('mousedown', press, true)
    window.addEventListener('mouseup', release, true)
    window.addEventListener(NAVIGATE_EVENT, fromShell)

    return () => {
      window.removeEventListener('mousedown', press, true)
      window.removeEventListener('mouseup', release, true)
      window.removeEventListener(NAVIGATE_EVENT, fromShell)
    }
  }, [travelTo])

  const focusItems = useMemo(() => {
    if (!focus) return null

    const item = (id: string, related: boolean): FocusItem | null => {
      const node = map.get(id)

      if (!node || !isTask(node)) return null

      const parent = node.parentId ? map.get(node.parentId) : undefined
      const status = work.status.get(id) ?? 'ready'

      return {
        id,
        label: node.data.label || (isNote(node) ? 'Empty note' : 'Untitled'),
        tag: isNote(node) ? 'Note' : getTaskTag(node.data),
        status,
        where: parent ? (parent.data as ClusterData).label : 'Loose work',
        related,
        flow: work.flow.get(id) ?? 'live',
      }
    }

    const incoming: FocusItem[] = []
    const outgoing: FocusItem[] = []

    for (const link of links) {
      if (link.to === focus && !incoming.some((incomingItem) => incomingItem.id === link.from)) {
        const incomingItem = item(link.from, link.kind === 'related')

        if (incomingItem) incoming.push(incomingItem)
      }

      if (link.from === focus && !outgoing.some((incomingItem) => incomingItem.id === link.to)) {
        const outgoingItem = item(link.to, link.kind === 'related')

        // A link reads by its source, and here the source is the focused card.
        if (outgoingItem) outgoing.push({ ...outgoingItem, flow: work.flow.get(focus) ?? 'live' })
      }
    }

    const settled = (item: FocusItem) => (item.status === 'done' || item.status === 'deferred' ? 1 : 0)

    return {
      incoming: incoming.sort((a, b) => settled(a) - settled(b)),
      outgoing: outgoing.sort((a, b) => settled(a) - settled(b)),
    }
  }, [focus, links, map, work])

  // ---- Drawing links ----

  /** A drawn link never replaces one that already joins the pair, whichever way it runs. */
  const connect = useCallback(
    (from: string, to: string) => {
      if (from === to) return

      setLinks((currentLinks) =>
        currentLinks.some((link) => (link.from === from && link.to === to) || (link.from === to && link.to === from))
          ? currentLinks
          : [...currentLinks, { id: `${from}>${to}`, from, to, kind: 'blocks' }],
      )
    },
    [setLinks],
  )
  const onConnect = useCallback((connection: Connection) => connect(connection.source, connection.target), [connect])
  const [linking, setLinking] = useState(false)
  /** Dropping a link anywhere on a card joins it, not only on the card's small handle. */
  const onConnectEnd = useCallback(
    (event: MouseEvent | TouchEvent, state: FinalConnectionState) => {
      setLinking(false)

      if (state.isValid || !state.fromNode || !state.fromHandle) return

      const point = 'changedTouches' in event ? event.changedTouches[0] : event
      const dropped = document.elementFromPoint(point.clientX, point.clientY)?.closest<HTMLElement>('.react-flow__node-task')?.dataset.id

      if (!dropped) return

      if (state.fromHandle.type === 'source') connect(state.fromNode.id, dropped)
      else connect(dropped, state.fromNode.id)
    },
    [connect],
  )

  const selected = nodes.filter((node) => node.selected && !view.hidden.has(node.id))

  // Reported again on focus so the page the person is using wins over other open pages.
  const focusReportKey = JSON.stringify({ open: root, selected: selected.map((node) => node.id) } satisfies FocusReport)

  useEffect(() => {
    if (!ready) return

    const workspaceName = workspace.current
    const report = () => reportFocus(JSON.parse(focusReportKey) as FocusReport, workspaceName)
    const reportTimer = setTimeout(report, 150)

    window.addEventListener('focus', report)
    window.addEventListener('pageshow', report)

    return () => {
      clearTimeout(reportTimer)
      window.removeEventListener('focus', report)
      window.removeEventListener('pageshow', report)
    }
  }, [focusReportKey, ready, workspaces.active])
  useEffect(() => {
    const close = () => clearFocus(workspace.current)

    window.addEventListener('pagehide', close)

    return () => window.removeEventListener('pagehide', close)
  }, [])

  const doGroup = useCallback(() => {
    const visibleSel = nodes.map((node) => (node.selected && view.hidden.has(node.id) ? { ...node, selected: false } : node))
    const result = groupSelection(visibleSel, cardSize)

    if (!result) return

    setNodes(result.nodes)
    setEditing(result.groupId)
  }, [nodes, view, setNodes, cardSize])

  const doUngroup = useCallback(
    (ids?: string[]) => {
      const targets = ids ?? selected.filter(isCluster).map((node) => node.id)

      if (!targets.length) return

      if (root && targets.includes(root)) openRoot(map.get(root)?.parentId ?? null)

      setNodes(ungroup(nodes, targets, cardSize))
    },
    [nodes, selected, root, map, openRoot, setNodes, cardSize],
  )

  const actions = useMemo(
    () => ({
      reflow: (groupId: string) => {
        const { nodes: currentNodes, links: currentLinks } = latest.current

        reflow(currentNodes, currentLinks, groupId, cardSize).then(tweenTo)
      },
      open: (groupId: string) => {
        openRoot(groupId)
        setHover(null)
      },
    }),
    [tweenTo, openRoot, setHover, cardSize],
  )

  const arrangeGroup = useCallback(
    (groupId: string, patch: Pick<ClusterData, 'arrange'>) => {
      const { nodes: currentNodes, links: currentLinks } = latest.current
      const next = currentNodes.map((node) => (node.id === groupId && isCluster(node) ? { ...node, data: { ...node.data, ...patch } } : node))

      reflow(next, currentLinks, groupId, cardSize).then(tweenTo)
    },
    [tweenTo, cardSize],
  )

  const updateData = useCallback(
    (id: string, patch: Partial<TaskData> | Partial<ClusterData> | Partial<ImageNode['data']>) =>
      setNodes((currentNodes) => currentNodes.map((node) => (node.id === id ? ({ ...node, data: { ...node.data, ...patch } } as AppNode) : node))),
    [setNodes],
  )

  // ---- Notes and links ----

  /** Adds a note, or a work item with `itemKind: 'step'`, with its top-left at `at` (flow coordinates), optionally spliced into links. */
  const addNote = useCallback(
    (
      at: { x: number; y: number },
      options: { parent?: string | null; from?: string; to?: string; replace?: string; itemKind?: 'note' | 'step' } = {},
    ) => {
      const { nodes: currentNodes, links: currentLinks } = latest.current
      const nodeMap = byId(currentNodes)
      const parent = options.parent === undefined ? root : options.parent
      const parentNode = parent ? nodeMap.get(parent) : undefined
      const origin = parentNode ? absolutePosition(parentNode, nodeMap) : { x: 0, y: 0 }
      const itemKind = options.itemKind ?? 'note'
      const id = newId(itemKind === 'note' ? 'note' : 'card')
      const note: AppNode = {
        id,
        type: 'task',
        parentId: parentNode?.id,
        position: { x: at.x - origin.x, y: at.y - origin.y },
        data: { kind: 'task', label: '', itemKind, status: 'todo' },
        selected: true,
      }
      const kind = currentLinks.find((link) => link.id === options.replace)?.kind ?? 'blocks'
      const next = currentLinks.filter((link) => link.id !== options.replace)

      if (options.from) next.push({ id: `${options.from}>${id}`, from: options.from, to: id, kind })

      if (options.to) next.push({ id: `${id}>${options.to}`, from: id, to: options.to, kind })

      const nextNodes = normalize([...currentNodes.map((node) => (node.selected ? { ...node, selected: false } : node)), note], cardSize)

      setNodes(nextNodes)
      setLinks(next)
      setEditing(id)

      // An automatic group lays out its new item in line. Only positions and sizes come back, so text typed meanwhile stays.
      if (options.replace && parentNode && isCluster(parentNode) && parentNode.data.arrange !== 'custom')
        void reflow(nextNodes, next, parentNode.id).then((laidOut) => {
          const placed = byId(laidOut)

          setNodes((latestNodes) =>
            latestNodes.map((node) => {
              const placedNode = placed.get(node.id)

              if (!placedNode) return node

              return { ...node, position: placedNode.position, width: placedNode.width, height: placedNode.height }
            }),
          )
        })
    },
    [root, setLinks, setNodes, cardSize],
  )

  const viewportCenter = useCallback(() => {
    const rectangle = canvasRef.current?.getBoundingClientRect()

    if (!rectangle) return { x: 0, y: 0 }

    const center = reactFlow.screenToFlowPosition({ x: rectangle.left + rectangle.width / 2, y: rectangle.top + rectangle.height / 2 })

    return { x: center.x - cardSize.width / 2, y: center.y - cardSize.height / 2 }
  }, [reactFlow, cardSize])

  const addImage = useCallback(
    async (file: File) => {
      const workspaceEpochAtStart = workspaceEpoch.current
      const workspaceName = workspace.current
      const parentId = root

      setImageError(null)

      try {
        const { asset } = await importImage(file, workspaceName)

        if (workspaceEpochAtStart !== workspaceEpoch.current) return

        const position = viewportCenter()

        setNodes((currentNodes) => {
          const nodeMap = byId(currentNodes)
          const parentNode = parentId ? nodeMap.get(parentId) : undefined
          const origin = parentNode ? absolutePosition(parentNode, nodeMap) : { x: 0, y: 0 }
          const image: ImageNode = {
            id: newId('image'),
            type: 'image',
            parentId: parentNode?.id,
            position: { x: position.x - 20 - origin.x, y: position.y - 92 - origin.y },
            width: 256,
            height: 256,
            data: { kind: 'image', label: file.name.replace(/\.[^.]+$/, ''), asset, workspace: workspaceName },
            selected: true,
          }

          return normalize([...currentNodes.map((node) => (node.selected ? { ...node, selected: false } : node)), image], cardSize)
        })
      } catch (error) {
        setImageError(error instanceof Error ? error.message : 'Could not add the image.')
      }
    },
    [root, viewportCenter, setNodes, cardSize],
  )

  /** The innermost visible card or group under a canvas point that `accept` allows. */
  const nodeAt = useCallback(
    (point: { x: number; y: number }, accept: (node: AppNode) => boolean) => {
      let found: string | null = null
      let depth = -1

      for (const node of nodes) {
        if (view.hidden.has(node.id) || !inView(node.id) || !accept(node)) continue

        const position = absolutePosition(node, map)
        const size = sizeOf(node, cardSize)
        const nodeDepth = ancestors(node.id, map).length

        if (
          point.x >= position.x &&
          point.x <= position.x + size.width &&
          point.y >= position.y &&
          point.y <= position.y + size.height &&
          nodeDepth > depth
        ) {
          found = node.id
          depth = nodeDepth
        }
      }

      return found
    },
    [nodes, map, view, inView, cardSize],
  )

  /** Drops a note centered on a click, inside the innermost open group under it. */
  const placeComment = useCallback(
    (event: React.MouseEvent) => {
      const point = reactFlow.screenToFlowPosition({ x: event.clientX, y: event.clientY })
      const parent = nodeAt(point, (node) => isCluster(node) && !collapsed.has(node.id)) ?? root

      addNote({ x: point.x - cardSize.width / 2, y: point.y - cardSize.height / 2 }, { parent })
      setTool('select')
    },
    [reactFlow, nodeAt, collapsed, root, addNote, cardSize],
  )

  // ---- Stickers ----

  /** Where a sticker dropped at a canvas point sits: on the card or group under it, or loose. */
  const anchorAt = useCallback(
    (point: { x: number; y: number }) => {
      const on = nodeAt(point, () => true)
      const node = on ? map.get(on) : undefined

      if (!node) return { x: Math.round(point.x), y: Math.round(point.y) }

      const position = absolutePosition(node, map)

      return { x: Math.round(point.x - position.x), y: Math.round(point.y - position.y), on: node.id }
    },
    [nodeAt, map],
  )

  const stamp = useCallback(
    (event: React.MouseEvent) => {
      const id = newId('sticker')
      const at = anchorAt(reactFlow.screenToFlowPosition({ x: event.clientX, y: event.clientY }))

      setStickers((stickers) => [...stickers, { id, kind: sticker, tilt: Math.round((Math.random() * 2 - 1) * STICKER_TILT), ...at }])
      setFresh((freshStickers) => new Set(freshStickers).add(id))
      setTimeout(
        () =>
          setFresh((freshStickers) => {
            const next = new Set(freshStickers)

            next.delete(id)

            return next
          }),
        STICKER_FRESH_MS,
      )
    },
    [reactFlow, sticker, anchorAt],
  )

  const settleStickers = useCallback(
    (moves: StickerMove[]) => {
      const landed = new Map(moves.map((move) => [move.id, move]))

      setStickers((stickers) =>
        stickers.map((sticker) => {
          const at = landed.get(sticker.id)

          return at ? { id: sticker.id, kind: sticker.kind, tilt: sticker.tilt, ...anchorAt(at) } : sticker
        }),
      )
    },
    [anchorAt],
  )

  /** Every group frame on screen, which stickers bounce inside and off of. */
  const stickerBounds = useMemo<StickerBounds[]>(() => {
    const shown = nodes.filter((node) => isCluster(node) && !view.hidden.has(node.id) && inView(node.id))
    const ids = new Set(shown.map((node) => node.id))

    return shown.map((node) => {
      const position = absolutePosition(node, map)
      const size = sizeOf(node, cardSize)
      const chain = ancestors(node.id, map)

      return {
        id: node.id,
        x0: position.x,
        y0: position.y,
        x1: position.x + size.width,
        y1: position.y + size.height,
        parent: chain.find((ancestor) => ids.has(ancestor)) ?? null,
        depth: chain.length,
      }
    })
  }, [nodes, map, view, inView, cardSize])

  const placedStickers = useMemo<PlacedSticker[]>(
    () =>
      stickers.flatMap((sticker) => {
        if (!sticker.on) return [{ ...sticker, fresh: fresh.has(sticker.id) }]

        const node = map.get(sticker.on)

        if (!node || view.hidden.has(node.id)) return []

        const position = absolutePosition(node, map)

        return [{ ...sticker, x: position.x + sticker.x, y: position.y + sticker.y, fresh: fresh.has(sticker.id) }]
      }),
    [stickers, map, view, fresh],
  )

  /** Picking Sticker opens the wheel: above its button, or at the cursor when S is held. */
  const chooseTool = useCallback((next: Tool, from?: DOMRect) => {
    if (next !== 'sticker') {
      setWheel(null)
      setTool(next)

      return
    }

    if (from) {
      setWheel({ x: from.left + from.width / 2, y: from.top - WHEEL_LIFT, held: false })

      return
    }

    const rectangle = canvasRef.current?.getBoundingClientRect()
    const position = pointer.current

    if (rectangle)
      setWheel({ x: rectangle.left + (position?.x ?? rectangle.width / 2), y: rectangle.top + (position?.y ?? rectangle.height / 2), held: true })
  }, [])

  const assignSlot = useCallback(
    (slot: number, emoji: string | null) => setLoadout((loadout) => loadout.map((sticker, i) => (i === slot ? emoji : sticker))),
    [],
  )

  const pickSticker = useCallback((id: string) => {
    setSticker(id)
    setTool('sticker')
    setWheel(null)
  }, [])

  /** Splits a link with a new note or work item placed between its ends. */
  const insertOnLink = (linkId: string, itemKind: 'note' | 'step') => {
    const link = links.find((candidate) => candidate.id === linkId)
    const sourceNode = link && map.get(link.from)
    const targetNode = link && map.get(link.to)

    if (!link || !sourceNode || !targetNode) return

    const sourcePosition = absolutePosition(sourceNode, map)
    const targetPosition = absolutePosition(targetNode, map)
    const chainB = [targetNode.parentId, ...ancestors(targetNode.id, map)]
    const parent = [sourceNode.parentId, ...ancestors(sourceNode.id, map)].find((position) => position && chainB.includes(position)) ?? null

    addNote(
      { x: (sourcePosition.x + targetPosition.x) / 2, y: (sourcePosition.y + targetPosition.y) / 2 + cardSize.height },
      { parent, from: link.from, to: link.to, replace: link.id, itemKind },
    )
  }

  /** Removes a note and reconnects whatever ran through it. */
  const deleteNote = (id: string) => {
    setLinks((currentLinks) => {
      const incomingLinks = currentLinks.filter((link) => link.to === id)
      const outgoingLinks = currentLinks.filter((link) => link.from === id)
      const next = currentLinks.filter((link) => link.from !== id && link.to !== id)

      for (const incomingLink of incomingLinks)
        for (const outgoingLink of outgoingLinks)
          if (!next.some((link) => link.from === incomingLink.from && link.to === outgoingLink.to))
            next.push({
              id: `${incomingLink.from}>${outgoingLink.to}`,
              from: incomingLink.from,
              to: outgoingLink.to,
              kind: incomingLink.kind === 'blocks' && outgoingLink.kind === 'blocks' ? 'blocks' : 'related',
            })

      return next
    })
    setNodes((currentNodes) =>
      normalize(
        currentNodes.filter((node) => node.id !== id),
        cardSize,
      ),
    )
  }

  const removeLink = (id: string) => setLinks((currentLinks) => currentLinks.filter((link) => link.id !== id))
  /** One link per pair of cards: adding a link replaces whatever already joined them. */
  const addLink = (from: string, to: string, kind: Link['kind']) =>
    setLinks((currentLinks) => [
      ...currentLinks.filter((link) => !((link.from === from && link.to === to) || (link.from === to && link.to === from))),
      { id: `${from}>${to}`, from, to, kind },
    ])
  const flipLink = (id: string) =>
    setLinks((currentLinks) => currentLinks.map((link) => (link.id === id ? { ...link, kind: link.kind === 'blocks' ? 'related' : 'blocks' } : link)))

  const tidy = () => reflow(nodes, links, root ?? undefined, cardSize).then(tweenTo)
  const rootCustom = !!root && (map.get(root)?.data as ClusterData | undefined)?.arrange === 'custom'

  // ---- Context menu ----

  const openMenu = (event: MouseEvent | React.MouseEvent, target: Menu['target']) => {
    event.preventDefault()
    setMenu({ x: event.clientX, y: event.clientY, flow: reactFlow.screenToFlowPosition({ x: event.clientX, y: event.clientY }), target })
  }

  /** A shortcut as menus and the palette show it, or nothing when it's unbound. */
  const hintOf = (id: ShortcutId) => formatChord(keybindings[id]) || undefined

  const menuItems = (menu: Menu): MenuItem[] => {
    const target = menu.target

    if (target.kind === 'sticker')
      return [{ label: 'Remove sticker', danger: true, run: () => setStickers((stickers) => stickers.filter((sticker) => sticker.id !== target.id)) }]

    if (target.kind === 'edge' && target.id.startsWith('agg:')) {
      const key = target.id.slice('agg:'.length)
      const bundled = links.filter((link) => {
        const ends = link.kind === 'blocks' && drawnEnds(link)

        return ends && `${ends.source}>${ends.target}` === key
      })
      const labelOf = (id: string) => map.get(id)?.data.label || 'Untitled'

      return bundled.map((link) => ({ label: `Remove ${labelOf(link.from)} → ${labelOf(link.to)}`, danger: true, run: () => removeLink(link.id) }))
    }

    if (target.kind === 'edge') {
      const link = links.find((candidate) => candidate.id === target.id)

      if (!link) return []

      return [
        { label: 'Add card here', run: () => insertOnLink(link.id, 'step') },
        { label: 'Insert a note here', run: () => insertOnLink(link.id, 'note') },
        { label: link.kind === 'blocks' ? 'Make it a related link' : 'Make it a blocking link', run: () => flipLink(link.id) },
        'divider',
        { label: 'Remove link', danger: true, run: () => removeLink(link.id) },
      ]
    }

    if (target.kind === 'node') {
      if (target.id.startsWith('ghost:')) {
        const taskId = target.id.split(':')[2]

        return [{ label: 'Jump to it', run: () => jumpTo(taskId) }]
      }

      const node = map.get(target.id)

      if (!node) return []

      const many: MenuItem[] =
        selected.length > 1 ? [{ label: `Group ${selected.length} selected`, hint: hintOf('group'), run: doGroup }, 'divider'] : []

      if (isCluster(node))
        return [
          ...many,
          { label: 'Open', hint: hintOf('open-group'), run: () => actions.open(node.id) },
          { label: 'Rename', run: () => (selectOnly(node.id), setEditing(node.id)) },
          ...(node.data.arrange === 'custom' ? [] : [{ label: 'Reflow', run: () => actions.reflow(node.id) }]),
          { label: 'Ungroup', hint: hintOf('ungroup'), run: () => doUngroup([node.id]) },
        ]

      const position = absolutePosition(node, map)
      const after = { x: position.x + cardSize.width + 48, y: position.y + cardSize.height + 24 }

      if (isNote(node))
        return [
          ...many,
          { label: 'Edit note', run: () => (selectOnly(node.id), setEditing(node.id)) },
          { label: 'Turn into a work item', run: () => updateData(node.id, { itemKind: 'step', status: 'todo' }) },
          'divider',
          { label: 'Delete note', danger: true, run: () => deleteNote(node.id) },
        ]

      if (isImage(node))
        return [
          ...many,
          { label: 'Rename image', run: () => (selectOnly(node.id), setEditing(node.id)) },
          'divider',
          {
            label: 'Remove image',
            danger: true,
            run: () =>
              setNodes((currentNodes) =>
                normalize(
                  currentNodes.filter((item) => item.id !== node.id),
                  cardSize,
                ),
              ),
          },
        ]

      const data = node.data as TaskData
      const url = getTaskUrl(data)

      return [
        ...many,
        ...(url ? [{ label: `Open ${getTaskTag(data)}`, hint: '↗', run: () => openExternal(url) }] : []),
        data.status === 'done'
          ? { label: 'Mark not done', run: () => updateData(node.id, { status: 'todo' }) }
          : { label: 'Mark done', run: () => updateData(node.id, { status: 'done' }) },
        { label: 'Add a note after this', run: () => addNote(after, { parent: node.parentId ?? null, from: node.id }) },
        ...(node.parentId !== root ? [{ label: 'Open its group', run: () => jumpTo(node.id) }] : []),
      ]
    }

    return [
      { label: 'Add a note here', hint: hintOf('add-note'), run: () => addNote(menu.flow) },
      ...(selected.length > 1 ? [{ label: `Group ${selected.length} selected`, hint: hintOf('group'), run: doGroup }] : []),
      'divider',
      ...(rootCustom ? [] : [{ label: root ? 'Tidy this group' : 'Tidy canvas', run: tidy }]),
      { label: 'Fit to screen', hint: hintOf('fit'), run: () => fitTo(root) },
      ...(root ? [{ label: 'Go up a level', hint: hintOf('step-back'), run: () => openRoot(map.get(root)?.parentId ?? null) }] : []),
    ]
  }

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if ((event.target as HTMLElement).closest('input, textarea, select, [contenteditable="true"]')) return

      const pressed = (id: ShortcutId) => matchesChord(event, keybindings[id])

      if (pressed('actions')) {
        event.preventDefault()
        setPaletteQuery(COMMAND_PREFIX)

        return
      }

      if (pressed('search')) {
        event.preventDefault()
        setPaletteQuery('')

        return
      }

      if (pressed('settings')) {
        event.preventDefault()
        setPaletteQuery(null)
        setSettings('appearance')

        return
      }

      if (paletteOpen) return

      if (pressed('go-back') || pressed('go-forward')) {
        event.preventDefault()
        travelTo(pressed('go-back') ? 'back' : 'forward')

        return
      }

      if (pressed('undo') || pressed('redo')) {
        event.preventDefault()

        if (pressed('redo')) redo()
        else undo()

        return
      }

      if (focus) {
        if (pressed('step-back')) exitFocus()

        return
      }

      if (pressed('less-detail') || pressed('more-detail')) {
        event.preventDefault()
        changeDetail(pressed('less-detail') ? -1 : 1)

        return
      }

      if (pressed('group')) {
        event.preventDefault()
        doGroup()
      } else if (pressed('ungroup')) {
        event.preventDefault()
        doUngroup()
      } else if (pressed('open-group') && selected.length === 1 && isCluster(selected[0])) {
        actions.open(selected[0].id)
      } else if (pressed('step-back')) {
        if (tool !== 'select') setTool('select')
        else if (pinned) setPinned(null)
        else if (root) openRoot(map.get(root)?.parentId ?? null)
        else setNodes((currentNodes) => currentNodes.map((node) => (node.selected ? { ...node, selected: false } : node)))
      } else if (pressed('fit')) {
        fitTo(root)
      } else if (pressed('add-note')) {
        event.preventDefault()
        addNote(viewportCenter())
      }
    }

    window.addEventListener('keydown', onKey)

    return () => window.removeEventListener('keydown', onKey)
  }, [
    keybindings,
    doGroup,
    doUngroup,
    selected,
    actions,
    root,
    map,
    fitTo,
    addNote,
    viewportCenter,
    pinned,
    openRoot,
    tool,
    paletteOpen,
    focus,
    exitFocus,
    travelTo,
    changeDetail,
    undo,
    redo,
    setNodes,
    setPinned,
  ])

  const crumbs = root ? [...ancestors(root, map).reverse(), root] : []
  const one = selected.length === 1 ? selected[0] : null
  const focused = focus ? map.get(focus) : undefined
  const focusPos = focused && absolutePosition(focused, map)
  const focusSize = focused && sizeOf(focused, cardSize)
  const readyTotal = [...work.status.values()].filter((status) => status === 'ready').length

  const commands: Command[] = [
    ...(trailSize.back
      ? [{ id: 'go-back', label: 'Go back', detail: 'Return to the previous view', hint: hintOf('go-back'), run: () => travelTo('back') }]
      : []),
    ...(trailSize.forward
      ? [
          {
            id: 'go-forward',
            label: 'Go forward',
            detail: 'Return to the view you went back from',
            hint: hintOf('go-forward'),
            run: () => travelTo('forward'),
          },
        ]
      : []),
    ...(level > 1
      ? [
          {
            id: 'less-detail',
            label: 'Show less detail',
            detail: 'Fold one more level of groups',
            hint: hintOf('less-detail'),
            run: () => changeDetail(-1),
          },
        ]
      : []),
    ...(level < levels
      ? [
          {
            id: 'more-detail',
            label: 'Show more detail',
            detail: 'Open one more level of groups',
            hint: hintOf('more-detail'),
            run: () => changeDetail(1),
          },
        ]
      : []),
    ...(canUndo ? [{ id: 'undo', label: 'Undo', detail: 'Take back the last canvas edit', hint: hintOf('undo'), run: undo }] : []),
    ...(canRedo ? [{ id: 'redo', label: 'Redo', detail: 'Make the last undone edit again', hint: hintOf('redo'), run: redo }] : []),
    {
      id: 'fit-board',
      label: 'Fit entire board',
      detail: 'Show all work',
      hint: root ? undefined : hintOf('fit'),
      run: () => (root ? openRoot(null) : fitTo(null)),
    },
    ...(selected.length
      ? [
          {
            id: 'fit-selection',
            label: 'Fit selection',
            detail: `Show ${selected.length} selected`,
            run: () =>
              void reactFlow.fitView({ nodes: selected.map((node) => ({ id: node.id })), padding: 0.2, maxZoom: FIT_MAX_ZOOM, duration: glide(450) }),
          },
        ]
      : []),
    ...THEMES.map((theme) => ({
      id: `theme-${theme.id}`,
      label: `Theme: ${theme.label}`,
      detail: 'Saved on this device',
      run: () => chooseAppearance({ ...appearance, theme: theme.id }),
    })),
    ...SKINS.map((skin) => ({
      id: `skin-${skin.id}`,
      label: `Cards: ${skin.label}`,
      detail: 'Saved on this device',
      run: () => chooseAppearance({ ...appearance, skin: skin.id }),
    })),
    ...COLOR_MODES.map((mode) => ({
      id: `color-mode-${mode}`,
      label: `Color mode: ${mode[0].toUpperCase()}${mode.slice(1)}`,
      detail: 'Saved on this device',
      run: () => chooseAppearance({ ...appearance, colorMode: mode }),
    })),
    ...STATUS_COLORS.map((option) => ({
      id: `status-colors-${option.id}`,
      label: `Colorblind colors: ${option.label}`,
      detail: 'Saved on this device',
      run: () => chooseAppearance({ ...appearance, statusColors: option.id }),
    })),
    ...ANIMATIONS.map((option) => ({
      id: `animations-${option.id}`,
      label: `Animations: ${option.label}`,
      detail: 'Saved on this device',
      run: () => chooseAppearance(withMotion(appearance, option.id)),
    })),
    {
      id: 'settings',
      label: 'Open settings',
      detail: 'Theme, cards, color mode, accessibility, and keyboard shortcuts',
      hint: hintOf('settings'),
      run: () => setSettings('appearance'),
    },
    {
      id: 'keyboard-shortcuts',
      label: 'Open keyboard shortcuts',
      detail: 'See and change shortcuts',
      run: () => setSettings('shortcuts'),
    },
    {
      id: 'sidebar',
      label: sidebar ? 'Hide group list' : 'Show group list',
      detail: 'Groups and their progress',
      run: () => toggleSidebar(!sidebar),
    },
    {
      id: 'sync',
      label: 'Sync with GitHub',
      detail: 'Refresh pull request status now',
      run: () => void requestSync(true).then((status) => status && setSyncStatus(status)),
    },
    {
      id: 'reload',
      label: 'Reload window',
      detail: 'Load the app again',
      run: () => window.location.reload(),
    },
    {
      id: 'debug-bar',
      label: debug ? 'Hide debug bar' : 'Show debug bar',
      detail: 'Frame rate and animation toggles',
      run: () => toggleDebug(!debug),
    },
  ]

  const toggleSidebar = (value: boolean) => {
    setSidebar(value)
    writeFlag('sidebar', value)
  }

  const toggleDebug = (v: boolean) => {
    setDebug(v)
    writeFlag('debug', v)
  }

  const changeMotion = (next: MotionSettings) => {
    setMotion(next)

    if (!next.pauseWhileMoving) canvasRef.current?.removeAttribute('data-moving')

    saveSettings({ motion: JSON.stringify(next) })
  }

  const chooseAppearance = (next: Appearance) => {
    setAppearance(next)
    writeAppearance(next)
  }

  const chooseKeybindings = (next: Keybindings) => {
    setKeybindings(next)
    writeKeybindings(next)
  }

  return (
    <ActionsContext.Provider value={actions}>
      <div className="app">
        {sidebar && (
          <Sidebar
            nodes={nodes}
            groups={work.groups}
            root={root}
            open={openRoot}
            readyTotal={readyTotal}
            hide={() => toggleSidebar(false)}
            workspaces={workspaces}
            switchWorkspace={switchWorkspace}
            newWorkspace={newWorkspace}
            openSettings={() => setSettings('appearance')}
            settingsHint={hintOf('settings') ?? ''}
          />
        )}
        <div
          className={`canvas tool-${tool}${attending ? ' is-attending' : ''}${inspecting ? ' is-inspecting' : ''}${trace ? ' is-tracing' : ''}${focus ? ' is-focus' : ''}${linking ? ' is-linking' : ''}${still ? ' is-still' : ''}${quietZoom ? ' is-quiet' : ''}${away ? ' is-away' : ''}${motion.arrows ? '' : ' no-arrow-motion'}${motion.glow ? '' : ' no-glow'}${debug ? ' has-debug' : ''}`}
          style={tool === 'sticker' ? ({ '--sticker-cursor': stickerCursor(sticker) } as CSSProperties) : undefined}
          ref={canvasRef}
          onPointerDown={startMarquee}
          onPointerMove={trackPointer}
          onClickCapture={claimNodeClick}
        >
          {ready && (
            <ReactFlow<ViewNode, Edge>
              fitView={!savedView}
              fitViewOptions={INITIAL_FIT}
              defaultViewport={savedView ?? undefined}
              onMoveStart={onMoveStart}
              onMoveEnd={rememberView}
              nodes={viewNodes}
              edges={edges}
              nodeTypes={nodeTypes}
              edgeTypes={edgeTypes}
              onNodesChange={onNodesChange}
              onNodeDragStop={onDragStop}
              onConnect={onConnect}
              onConnectStart={() => {
                setLinking(true)
                setHover(null)
              }}
              onConnectEnd={onConnectEnd}
              onNodeMouseEnter={(_, node) =>
                !focus && !linking && setHover(node.type === 'task' ? node.id : node.type === 'ghost' ? node.data.taskId : null)
              }
              onNodeMouseLeave={() => setHover(null)}
              onNodeClick={(event, node) => {
                if (tool === 'sticker') return stamp(event)

                if (focus) return

                setPinned(null)

                if (node.type === 'ghost') {
                  afterClick(() => jumpTo(node.data.taskId))

                  return
                }
              }}
              onNodeDoubleClick={(event, node) => {
                cancelClick()

                if (tool === 'sticker' || focus) return

                if (event.shiftKey && node.type === 'task') {
                  if (isNote(node)) setEditing(node.id)
                  else setPinned(node.id)

                  return
                }

                if (node.type === 'task' || node.type === 'ghost') return focusOn(node.type === 'ghost' ? node.data.taskId : node.id)

                if (node.type !== 'cluster') return

                actions.open(node.id)
              }}
              onNodeDragStart={(event, _node, dragged) => onDragStart(event, dragged)}
              onNodeDrag={onDrag}
              onPaneClick={(event) => {
                if (focus) return exitFocus()

                setPinned(null)

                // A double-click on empty canvas goes up out of the open group.
                if (event.detail === 2 && root && tool === 'select') return openRoot(map.get(root)?.parentId ?? null)

                if (tool === 'comment') placeComment(event)
                else if (tool === 'sticker') stamp(event)
              }}
              onEdgeClick={() => setPinned(null)}
              onPaneContextMenu={(event) => (focus ? event.preventDefault() : openMenu(event, { kind: 'pane' }))}
              onNodeContextMenu={(event, node) => {
                if (focus) return event.preventDefault()

                if (node.type !== 'ghost' && !node.selected) selectOnly(node.id)

                openMenu(event, { kind: 'node', id: node.id })
              }}
              onSelectionContextMenu={(event, currentNodes) => openMenu(event, { kind: 'node', id: currentNodes[0]?.id ?? '' })}
              onEdgeContextMenu={(event, edge) => openMenu(event, { kind: 'edge', id: edge.id })}
              panOnDrag={focus ? false : tool === 'hand' ? [0, 1] : [1]}
              selectionKeyCode={null}
              selectionOnDrag={false}
              nodesDraggable={!focus && (tool === 'select' || tool === 'comment' || (tool === 'hand' && commandHeld))}
              nodesConnectable={!focus && (tool === 'select' || tool === 'comment')}
              elementsSelectable={!focus && tool !== 'sticker'}
              panOnScroll={!focus}
              zoomOnScroll={false}
              zoomOnPinch={!focus}
              multiSelectionKeyCode={['Meta', 'Shift']}
              deleteKeyCode={null}
              zoomOnDoubleClick={false}
              minZoom={MIN_ZOOM}
              maxZoom={MAX_ZOOM}
              colorMode={colorModeOf(appearance)}
            >
              <StickerLayer
                stickers={placedStickers}
                interactive={!focus && tool === 'select'}
                bounds={stickerBounds}
                settle={settleStickers}
                menu={(event, id) => openMenu(event, { kind: 'sticker', id })}
              />
              {marquee && (
                <div
                  className="react-flow__selection marquee"
                  style={{ transform: `translate(${marquee.x}px, ${marquee.y}px)`, width: marquee.width, height: marquee.height }}
                />
              )}
              <Background variant={BackgroundVariant.Dots} gap={24} size={1.3} color="var(--dots)" />
              {nodes.length === 0 && <EmptyCanvas addNote={() => addNote(viewportCenter())} />}
              {guides.length > 0 && <SnapGuides guides={guides} zoom={reactFlow.getZoom()} />}
              <Controls showInteractive={false}>
                <DetailStepper level={level} levels={levels} keybindings={keybindings} change={changeDetail} />
              </Controls>
              {/* The desktop shell hides the native title bar, so this strip along the top drags the window. */}
              <div className="window-drag" data-tauri-drag-region aria-hidden="true" onPointerDown={(event) => event.stopPropagation()} />
              {mergeNotice !== null && (
                <Panel
                  position="bottom-left"
                  style={{ bottom: 100, margin: 15, padding: '8px 10px', maxWidth: 300, pointerEvents: 'none' }}
                  role="status"
                >
                  Merged with changes made elsewhere; kept yours for {mergeNotice} {mergeNotice === 1 ? 'field' : 'fields'}
                </Panel>
              )}
              {imageError && (
                <Panel position="bottom-left" style={{ bottom: 100, margin: 15, padding: '8px 10px', maxWidth: 300 }} role="alert">
                  {imageError}
                  <button type="button" className="link" onClick={() => setImageError(null)} aria-label="Dismiss image error">
                    ×
                  </button>
                </Panel>
              )}
              <MiniMap
                pannable
                zoomable
                nodeComponent={MiniMapNode}
                nodeClassName={(node) =>
                  node.type === 'cluster'
                    ? 'mm-cluster'
                    : node.type === 'image'
                      ? 'mm-image'
                      : node.type === 'ghost'
                        ? 'mm-ghost'
                        : 'mm-' + (work.status.get(node.id) ?? 'ready')
                }
              />

              <Panel position="top-left" className="panel crumbs" data-tauri-drag-region="deep">
                {!sidebar && (
                  <button type="button" className="crumb" onClick={() => toggleSidebar(true)} title="Show the group list">
                    ☰
                  </button>
                )}
                <button type="button" className={root ? 'crumb' : 'crumb current'} onClick={() => openRoot(null)}>
                  All work
                </button>
                {crumbs.map((id) => (
                  <span key={id} className="crumb-wrap">
                    <span className="sep">›</span>
                    <button type="button" className={id === root ? 'crumb current' : 'crumb'} onClick={() => openRoot(id)}>
                      {(map.get(id)?.data as ClusterData | undefined)?.label}
                    </button>
                  </span>
                ))}
              </Panel>
              <Panel position="center-left">
                <ActionBar
                  keybindings={keybindings}
                  search={() => setPaletteQuery('')}
                  addNote={() => addNote(viewportCenter())}
                  addImage={(file) => void addImage(file)}
                  tidy={rootCustom ? undefined : { label: `Tidy ${root ? 'group' : 'canvas'}`, run: tidy }}
                  sync={
                    syncStatus
                      ? {
                          status: syncStatus,
                          label:
                            syncStatus.state === 'running'
                              ? 'Syncing…'
                              : syncStatus.state === 'error'
                                ? 'Sync failed'
                                : syncStatus.state === 'unavailable'
                                  ? 'Sync unavailable'
                                  : syncStatus.lastRun
                                    ? `Synced ${relativeTime(syncStatus.lastRun, clock)}`
                                    : 'Sync now',
                          run: () => void requestSync(true).then((status) => status && setSyncStatus(status)),
                        }
                      : undefined
                  }
                />
              </Panel>

              {selected.length > 0 && (
                <Panel position="top-right" className="panel inspector">
                  {!one ? (
                    <div className="insp">
                      <strong>{selected.length} selected</strong>
                      <button type="button" className="btn primary" onClick={doGroup}>
                        Group selection <kbd>⌘G</kbd>
                      </button>
                    </div>
                  ) : isNote(one) ? (
                    <NoteInspector
                      key={one.id}
                      node={one}
                      focus={editing === one.id}
                      doneEditing={() => setEditing(null)}
                      update={updateData}
                      remove={() => deleteNote(one.id)}
                    />
                  ) : isTask(one) ? (
                    <TaskInspector
                      key={one.id}
                      node={one}
                      focus={editing === one.id}
                      doneEditing={() => setEditing(null)}
                      work={work}
                      map={map}
                      github={github}
                      update={updateData}
                      jumpTo={jumpTo}
                      links={links}
                      addLink={addLink}
                      removeLink={removeLink}
                      flipLink={flipLink}
                    />
                  ) : isImage(one) ? (
                    <div className="insp" key={one.id}>
                      <label htmlFor="image-label">Image label</label>
                      <input
                        id="image-label"
                        value={one.data.label}
                        autoFocus={editing === one.id}
                        onFocus={(event) => editing === one.id && event.target.select()}
                        onBlur={() => setEditing(null)}
                        onKeyDown={(event) => event.key === 'Enter' && event.currentTarget.blur()}
                        onChange={(event) => updateData(one.id, { label: event.target.value })}
                      />
                      <button
                        type="button"
                        className="btn"
                        onClick={() =>
                          setNodes((ns) =>
                            normalize(
                              ns.filter((n) => n.id !== one.id),
                              cardSize,
                            ),
                          )
                        }
                      >
                        Remove image
                      </button>
                    </div>
                  ) : (
                    <div className="insp" key={one.id}>
                      <label htmlFor="g-label">Group name</label>
                      <input
                        id="g-label"
                        value={(one.data as ClusterData).label}
                        autoFocus={editing === one.id}
                        onFocus={(event) => editing === one.id && event.target.select()}
                        onBlur={() => setEditing(null)}
                        onKeyDown={(event) => event.key === 'Enter' && (event.target as HTMLInputElement).blur()}
                        onChange={(event) => updateData(one.id, { label: event.target.value })}
                      />
                      {(one.data as ClusterData).blurb && <p className="blurb">{(one.data as ClusterData).blurb}</p>}
                      <GroupFacts stats={work.groups.get(one.id)} />
                      <GroupArrange data={one.data as ClusterData} change={(patch) => arrangeGroup(one.id, patch)} />
                      <div className="row">
                        <button type="button" className="btn primary" onClick={() => actions.open(one.id)}>
                          Open
                        </button>
                        {(one.data as ClusterData).arrange !== 'custom' && (
                          <button type="button" className="btn" onClick={() => actions.reflow(one.id)}>
                            Reflow
                          </button>
                        )}
                        <button type="button" className="btn" onClick={() => doUngroup([one.id])}>
                          Ungroup <kbd>⇧⌘G</kbd>
                        </button>
                      </div>
                    </div>
                  )}
                </Panel>
              )}

              <Panel position="bottom-center" className="dock">
                <Toolbar tool={tool} sticker={sticker} keybindings={keybindings} setTool={chooseTool} />
              </Panel>
            </ReactFlow>
          )}
          {ready && appearance.companion && !focus && (
            <Companion targets={companion.targets} describe={companion.describe} syncing={syncStatus?.state === 'running'} paused={away} />
          )}
          {attending && cursor && (
            <AttentionOverlay
              targets={attentionTargets}
              count={attention?.count ?? 0}
              elsewhere={attention?.elsewhere ?? 0}
              cursor={cursor}
              width={canvasSize.width}
              height={canvasSize.height}
              onJump={jumpTo}
            />
          )}
          {focused && focusPos && focusSize && focusItems && focusTransform && (
            <FocusView
              key={focused.id}
              label={focused.data.label || 'Note'}
              card={{
                x: focusPos.x * focusTransform[2] + focusTransform[0],
                y: focusPos.y * focusTransform[2] + focusTransform[1],
                width: focusSize.width * focusTransform[2],
                height: focusSize.height * focusTransform[2],
              }}
              sideWidth={FOCUS_SIDE_WIDTH}
              inset={FOCUS_INSET}
              incoming={focusItems.incoming}
              outgoing={focusItems.outgoing}
              onFocus={focusOn}
              onExit={exitFocus}
            >
              {isNote(focused) ? (
                <NoteInspector
                  node={focused}
                  focus={false}
                  doneEditing={() => setEditing(null)}
                  update={updateData}
                  remove={() => {
                    exitFocus()
                    deleteNote(focused.id)
                  }}
                />
              ) : (
                <TaskInspector
                  node={focused}
                  work={work}
                  map={map}
                  github={github}
                  update={updateData}
                  jumpTo={focusOn}
                  connections={false}
                  links={links}
                  addLink={addLink}
                  removeLink={removeLink}
                  flipLink={flipLink}
                />
              )}
            </FocusView>
          )}
          {!ready && <div className="loading">Laying out…</div>}
          {debug && <DebugBar canvas={canvasRef} motion={motion} setMotion={changeMotion} close={() => toggleDebug(false)} />}
          {menu && <ContextMenu x={menu.x} y={menu.y} items={menuItems(menu)} close={() => setMenu(null)} />}
          {wheel && (
            <StickerWheel
              at={wheel}
              held={wheel.held}
              holdKey={keybindings['tool-sticker']}
              current={sticker}
              loadout={loadout}
              pick={pickSticker}
              assign={assignSlot}
              close={() => setWheel(null)}
            />
          )}
        </div>
        {paletteQuery !== null && (
          <Palette
            nodes={nodes}
            commands={commands}
            jumpTo={jumpTo}
            open={actions.open}
            close={() => setPaletteQuery(null)}
            initialQuery={paletteQuery}
            recents={recents?.list}
            remember={rememberRecent}
          />
        )}
        {settings && (
          <Settings
            section={settings}
            showSection={setSettings}
            close={() => setSettings(null)}
            appearance={appearance}
            chooseAppearance={chooseAppearance}
            keybindings={keybindings}
            chooseKeybindings={chooseKeybindings}
          />
        )}
      </div>
    </ActionsContext.Provider>
  )
}
