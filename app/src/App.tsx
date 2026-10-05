import { useCallback, useEffect, useMemo, useRef, useState, type CSSProperties } from 'react'
import {
  Background,
  BackgroundVariant,
  Controls,
  MarkerType,
  MiniMap,
  Panel,
  Position,
  ReactFlow,
  ReactFlowProvider,
  applyNodeChanges,
  useReactFlow,
  useStore,
  useStoreApi,
  type Connection,
  type Edge,
  type NodeChange,
  type NodeTypes,
  type Viewport,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import { ContextMenu, type MenuItem } from './ContextMenu'
import { Palette } from './Palette'
import { AttentionOverlay, type AttentionTarget } from './attention'
import {
  ActionsContext,
  DerivedContext,
  deriveWork,
  needsAttention,
  traceFrom,
  type AttentionMark,
  type Derived,
  type Flow,
  type GroupStats,
} from './derive'
import { FocusView, type FocusItem } from './focus'
import { reflow, reflowAll } from './layout'
import { mergeDocs } from './merge'
import {
  STATUS_LABEL,
  TASK_H,
  TASK_W,
  absPos,
  ancestors,
  byId,
  descendants,
  groupSelection,
  isCluster,
  isNote,
  isTask,
  normalize,
  getTaskUrl,
  sizeOf,
  getTaskTag,
  githubSummary,
  relativeTime,
  ungroup,
  type AppNode,
  type ClusterData,
  type GhostNode,
  type GithubSnapshot,
  type Link,
  type Status,
  type TaskData,
  type Who,
} from './model'
import { ClusterView, GhostView, TaskView } from './nodes'
import {
  createWorkspace,
  clearFocus,
  fetchRemote,
  fingerprint,
  getSyncStatus,
  getWorkspaces,
  load,
  onRemoteChange,
  onSyncStatus,
  onWorkspaceChange,
  readBrowser,
  reportFocus,
  requestSync,
  save,
  setActiveWorkspace,
  type FocusReport,
  type Remote,
  type Saved,
  type SyncStatus,
  type Workspaces,
} from './persist'
import { seedLinks, seedNodes } from './seed'
import { Sidebar } from './Sidebar'
import { StickerLayer, StickerWheel, type PlacedSticker, type StickerBounds, type StickerMove } from './Stickers'
import { FALLBACK_STICKER, loadoutOf, stickerCursor, type Loadout, type Sticker } from './sticker'
import { Toolbar, type Tool } from './Toolbar'

type ViewNode = AppNode | GhostNode

const nodeTypes: NodeTypes = { task: TaskView, cluster: ClusterView, ghost: GhostView }
const SIDEBAR_KEY = 'orion:sidebar'
const COLOR_MODE_KEY = 'orion:color-mode'
type ColorMode = 'light' | 'dark' | 'system'
/**
 * Zoom below which a group reads as one body. Nested groups fold first as you
 * zoom out, so detail drops away from the inside.
 */
const COLLAPSE_ZOOM = 0.3
const COLLAPSE_STEP = 0.12
/** Zoom below which cards are too small for motion to read, so animations pause. */
const STILL_ZOOM = 0.45
const GHOST_W = 200
const GHOST_H = 62
const GHOST_GAP = 90
/** How much of the outside connections shows when a group opens. */
const GHOST_PEEK = 0.4
const FIT_MARGIN_Y = 90
const FIT_MAX_ZOOM = 1.25
/** How far across a card, on each side, the selection box has to reach to pick it up. */
const MARQUEE_REACH = 0.25
/**
 * Leaving a group means zooming out to this share of its opening zoom. Bigger groups
 * get zoomed out more just to look around, so they need more: about 0.64 for 9 items.
 */
const EXIT_RATIO_BASE = 0.95
const EXIT_RATIO_MAX = 0.8
const EXIT_RATIO_MIN = 0.45
const EXIT_RATIO_PER_DOUBLING = 0.1
const HINT_SPAN = 0.6
const PEEK_SPAN = 0.8
const PEEK_KEEP_VISIBLE = 0.4
const ATTEND_DELAY_MS = 150
/** A click on a group waits this long for a second one before it selects. */
const DOUBLE_CLICK_MS = 280
const FOCUS_SIDE_W = 248
const FOCUS_INSET = 20
const FOCUS_ZOOM = 1.2
/** The focused card sits this far down the canvas, leaving room for its details above. */
const FOCUS_CARD_Y = 0.7
const FOCUS_BOTTOM_GAP = 24
/** Focus moves head straight for the card and start fast. */
const FOCUS_MOVE = { duration: 260, ease: (t: number) => 1 - Math.pow(1 - t, 3), interpolate: 'linear' } as const
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

async function seeded() {
  const links = seedLinks()
  return { nodes: await reflowAll(seedNodes(), links), links }
}

function readFlag(key: string, fallback: boolean) {
  try {
    const v = localStorage.getItem(key)
    return v === null ? fallback : v === '1'
  } catch {
    return fallback
  }
}

function writeFlag(key: string, value: boolean) {
  try {
    localStorage.setItem(key, value ? '1' : '0')
  } catch {
    // Only a remembered preference.
  }
}

function readColorMode(): ColorMode {
  try {
    const mode = localStorage.getItem(COLOR_MODE_KEY)
    return mode === 'light' || mode === 'dark' ? mode : 'system'
  } catch {
    return 'system'
  }
}

function writeColorMode(mode: ColorMode) {
  try {
    localStorage.setItem(COLOR_MODE_KEY, mode)
  } catch {
    // Only a remembered preference.
  }
}

/** The stored shape of a document, for comparing and merging. */
const getCompactDoc = (doc: Saved): Saved =>
  JSON.parse(fingerprint({ ...doc, stickers: doc.stickers ?? [], stickerLoadout: loadoutOf(doc.stickerLoadout) })) as Saved

const ease = (t: number) => 1 - Math.pow(1 - t, 3)
const newId = (prefix: string) => prefix + '-' + Date.now().toString(36) + Math.random().toString(36).slice(2, 5)

function exitRatio(count: number) {
  return Math.max(EXIT_RATIO_MIN, Math.min(EXIT_RATIO_MAX, EXIT_RATIO_BASE - EXIT_RATIO_PER_DOUBLING * Math.log2(Math.max(count, 1))))
}

function groupFitViewport(group: AppNode, map: Map<string, AppNode>, box: { width: number; height: number }): Viewport {
  const p = absPos(group, map)
  const size = sizeOf(group)
  const width = size.w + 2 * (GHOST_GAP + GHOST_W * GHOST_PEEK)
  const height = size.h + FIT_MARGIN_Y * 2
  const zoom = Math.min(box.width / width, box.height / height, FIT_MAX_ZOOM)
  return { x: box.width / 2 - (p.x + size.w / 2) * zoom, y: box.height / 2 - (p.y + size.h / 2) * zoom, zoom }
}

/** Puts a card between the focus columns, a little larger than life. */
function focusViewport(card: AppNode, map: Map<string, AppNode>, box: { width: number; height: number }): Viewport {
  const p = absPos(card, map)
  const size = sizeOf(card)
  const zoom = FOCUS_ZOOM
  const centerY = Math.min(box.height * FOCUS_CARD_Y, box.height - FOCUS_BOTTOM_GAP - (size.h * zoom) / 2)
  return { x: box.width / 2 - (p.x + size.w / 2) * zoom, y: centerY - (p.y + size.h / 2) * zoom, zoom }
}

/**
 * Stacks newly created groups in columns to the right of everything else at the top
 * level, so laying them out never moves groups that were already placed.
 */
function placeBesideExisting(nodes: AppNode[], fresh: Set<string>): AppNode[] {
  const top = nodes.filter((n) => !n.parentId)
  const settled = top.filter((n) => !fresh.has(n.id))
  const right = settled.length ? Math.max(...settled.map((n) => n.position.x + sizeOf(n).w)) : 0
  const topY = settled.length ? Math.min(...settled.map((n) => n.position.y)) : 0
  const columnHeight = Math.max(1600, ...settled.map((n) => n.position.y + sizeOf(n).h - topY))
  const placed = new Map<string, { x: number; y: number }>()
  let x = right + PLACE_GAP * 2
  let y = topY
  let columnWidth = 0
  for (const group of top.filter((n) => fresh.has(n.id))) {
    const size = sizeOf(group)
    if (y > topY && y + size.h > topY + columnHeight) {
      x += columnWidth + PLACE_GAP
      y = topY
      columnWidth = 0
    }
    placed.set(group.id, { x, y })
    y += size.h + PLACE_GAP
    columnWidth = Math.max(columnWidth, size.w)
  }
  return nodes.map((n) => (placed.has(n.id) ? { ...n, position: placed.get(n.id)! } : n))
}

function Canvas() {
  const rf = useReactFlow<ViewNode, Edge>()
  const store = useStoreApi<ViewNode, Edge>()
  // Coarse zoom levels, so zooming re-renders the canvas only when one changes.
  const foldFrom = useStore((s) => Math.floor((s.transform[2] - COLLAPSE_ZOOM) / COLLAPSE_STEP) + 1)
  const still = useStore((s) => s.transform[2] < STILL_ZOOM)
  const [nodes, setNodes] = useState<AppNode[]>([])
  const [links, setLinks] = useState<Link[]>([])
  const [github, setGithub] = useState<GithubSnapshot | null>(null)
  const [githubOwner, setGithubOwner] = useState('flipbook-labs')
  const [syncStatus, setSyncStatus] = useState<SyncStatus | null>(null)
  const [workspaces, setWorkspaces] = useState<Workspaces>({ active: 'default', workspaces: [{ name: 'default', label: 'Default' }] })
  const [clock, setClock] = useState(() => Date.now())
  const [ready, setReady] = useState(false)
  const [root, setRoot] = useState<string | null>(null)
  const [peek, setPeek] = useState<string | null>(null)
  // Zoomed out past the leave point: the open group's surroundings show, faded.
  const peeking = root !== null && peek === root
  const [exitHint, setExitHint] = useState<{ root: string; progress: number } | null>(null)
  const [hover, setHover] = useState<string | null>(null)
  const [pinned, setPinned] = useState<string | null>(null)
  // A double-clicked card fills the view with what it waits on and leads to beside it.
  const [focusPick, setFocus] = useState<string | null>(null)
  // Where focus started, and whether it has since walked to another card or level.
  const focusEntry = useRef<{ viewport: Viewport; moved: boolean } | null>(null)
  const [editing, setEditing] = useState<string | null>(null)
  const [showHelp, setShowHelp] = useState(true)
  const [sidebar, setSidebar] = useState(() => readFlag(SIDEBAR_KEY, true))
  const [colorMode, setColorMode] = useState(readColorMode)
  const [menu, setMenu] = useState<Menu | null>(null)
  const [tool, setTool] = useState<Tool>('select')
  const [paletteOpen, setPaletteOpen] = useState(false)
  const [stickers, setStickers] = useState<Sticker[]>([])
  const [loadout, setLoadout] = useState<Loadout>(() => loadoutOf())
  const [chosenSticker, setSticker] = useState<string | null>(null)
  const sticker = chosenSticker ?? loadout.find((s) => s !== null) ?? FALLBACK_STICKER
  const [wheel, setWheel] = useState<{ x: number; y: number; held: boolean } | null>(null)
  const [fresh, setFresh] = useState<ReadonlySet<string>>(new Set())
  const canvasRef = useRef<HTMLDivElement>(null)
  const latest = useRef<Saved>({ nodes, links, stickers, stickerLoadout: loadout })
  const fitZoom = useRef(new Map<string, number>())
  const fitting = useRef(false)
  const fitSequence = useRef(0)
  const previousZoom = useRef(store.getState().transform[2])
  const skipNextFit = useRef(false)
  const openRoot = useCallback((target: string | null) => {
    setPeek(null)
    setExitHint(null)
    setFocus(null)
    focusEntry.current = null
    skipNextFit.current = false
    setRoot(target)
  }, [])

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
      for (const f of queued) f()
    }, DOUBLE_CLICK_MS)
  }, [])
  const cancelClick = useCallback(() => {
    clearTimeout(clickTimer.current)
    clickQueue.current = []
  }, [])
  useEffect(() => cancelClick, [cancelClick])
  // Runs before React Flow's own click handling, which selects the node as it goes.
  const claimNodeClick = (e: React.MouseEvent) => {
    const target = e.target as HTMLElement
    const node = target.closest('.react-flow__node')
    if (e.metaKey || e.shiftKey || e.ctrlKey || !node || target.closest('button, input, textarea, select')) return
    plainClick.current = node.classList.contains('react-flow__node-cluster') ? 'defer' : null
    setTimeout(() => (plainClick.current = null))
  }
  useEffect(() => {
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
    return store.subscribe((s) => apply(s.transform[2]))
  }, [store])

  // ---- Persistence ----
  const source = useRef<'file' | 'browser'>('file')
  const revision = useRef<number | null>(null)
  const savedPrint = useRef('')
  const base = useRef<Saved>({ nodes: [], links: [] })
  const [mergeNotice, setMergeNotice] = useState<number | null>(null)
  const noticeTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  // Saves and reloads run one at a time so a reload never lands on a half-finished save.
  const queue = useRef<Promise<void>>(Promise.resolve())
  const workspace = useRef('default')
  const workspaceEpoch = useRef(0)
  const pendingWorkspaceFit = useRef<number | null>(null)

  const adopt = useCallback((doc: Remote, serverDoc: Remote = doc, preserveSelection = true): Saved => {
    const next = normalize(doc.nodes)
    const server = getCompactDoc({
      nodes: normalize(serverDoc.nodes),
      links: serverDoc.links,
      stickers: serverDoc.stickers,
      stickerLoadout: serverDoc.stickerLoadout,
    })
    revision.current = doc.revision
    base.current = server
    savedPrint.current = fingerprint(server)
    const stickerLoadout = loadoutOf(doc.stickerLoadout)
    latest.current = { nodes: next, links: doc.links, stickers: doc.stickers ?? [], stickerLoadout }
    setNodes((ns) => {
      const picked = new Set(preserveSelection ? ns.filter((n) => n.selected).map((n) => n.id) : [])
      return picked.size ? next.map((n) => (picked.has(n.id) ? { ...n, selected: true } : n)) : next
    })
    setLinks(doc.links)
    setStickers(doc.stickers ?? [])
    setLoadout(stickerLoadout)
    setGithub(doc.github ?? null)
    setGithubOwner(doc.settings.githubOwner)
    return { nodes: next, links: doc.links, stickers: doc.stickers ?? [], stickerLoadout }
  }, [])

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
      const local = getCompactDoc(latest.current)
      if (fingerprint(local) === savedPrint.current) adopt(doc)
      else {
        const merged = mergeDocs(base.current, local, getCompactDoc(doc))
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
        adopt(loaded.doc, loaded.doc, !switched)
      } else {
        source.current = loaded.source === 'missing' ? 'file' : 'browser'
        const isDefault = name === 'default'
        const kept = isDefault ? (loaded.source === 'browser' ? loaded.saved : readBrowser()) : null
        const start = kept ? { nodes: normalize(kept.nodes), links: kept.links } : isDefault ? await seeded() : { nodes: [], links: [] }
        const initialStickers = kept?.stickers ?? []
        const initialLoadout = loadoutOf(kept?.stickerLoadout)
        if (epoch !== workspaceEpoch.current) return
        revision.current = null
        savedPrint.current = ''
        base.current = { nodes: [], links: [] }
        latest.current = { ...start, stickers: initialStickers, stickerLoadout: initialLoadout }
        setNodes(start.nodes)
        setLinks(start.links)
        setStickers(initialStickers)
        setLoadout(initialLoadout)
        setGithub(null)
        setGithubOwner('flipbook-labs')
      }
      setReady(true)
    },
    [adopt],
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
    const t = setTimeout(() => {
      // Stickers on cards or groups that are gone go with them.
      const ids = new Set(nodes.map((n) => n.id))
      const snapshot = { nodes, links, stickers: stickers.filter((s) => !s.on || ids.has(s.on)), stickerLoadout: loadout }
      const print = fingerprint(snapshot)
      const epoch = workspaceEpoch.current
      const name = workspace.current
      queue.current = queue.current.then(async () => {
        if (epoch !== workspaceEpoch.current) return
        if (print === savedPrint.current) return
        let pending: Saved = snapshot
        for (let attempt = 0; attempt <= 2; attempt++) {
          const result = await save(source.current, revision.current, pending, name)
          if (epoch !== workspaceEpoch.current) return
          if (result.ok) {
            revision.current = result.revision
            base.current = getCompactDoc(pending)
            savedPrint.current = fingerprint(pending)
            return
          }
          if (!result.conflict || attempt === 2) break
          const remote = await fetchRemote(name)
          if (epoch !== workspaceEpoch.current) return
          if (!remote) break
          const merged = mergeDocs(base.current, getCompactDoc(latest.current), getCompactDoc(remote))
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
    return () => clearTimeout(t)
  }, [nodes, links, stickers, loadout, ready, reload, adopt])

  const pendingLayoutEpoch = useRef<number | null>(null)
  useEffect(() => {
    const epoch = workspaceEpoch.current
    if (!ready || pendingLayoutEpoch.current === epoch) return
    const marked = nodes.filter((n) => isCluster(n) && n.data.layout)
    if (!marked.length) return
    const pending = marked.filter((n) => isCluster(n) && n.data.layout === 'pending')
    pendingLayoutEpoch.current = epoch
    void (async () => {
      let next = nodes
      try {
        for (const group of marked) {
          try {
            next = await reflow(next, links, group.id)
          } catch (error) {
            console.error('Could not lay out group', group.id, error)
          }
        }
        if (pending.length) next = placeBesideExisting(next, new Set(pending.map((g) => g.id)))
      } catch (error) {
        console.error('Could not lay out canvas', error)
      } finally {
        if (epoch === workspaceEpoch.current) {
          setNodes(next.map((n) => (isCluster(n) && n.data.layout ? { ...n, data: { ...n.data, layout: undefined } } : n)))
        }
        if (pendingLayoutEpoch.current === epoch) pendingLayoutEpoch.current = null
      }
    })()
  }, [nodes, links, ready])
  const changeWorkspace = useCallback(
    (name: string) => {
      if (name === workspace.current) return
      clearFocus(workspace.current)
      workspace.current = name
      const epoch = ++workspaceEpoch.current
      pendingWorkspaceFit.current = epoch
      setReady(false)
      setRoot(null)
      setPeek(null)
      setFocus(null)
      focusEntry.current = null
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
    [loadWorkspace],
  )

  useEffect(() => onWorkspaceChange(changeWorkspace), [changeWorkspace])

  useEffect(() => {
    if (!ready || pendingWorkspaceFit.current !== workspaceEpoch.current) return
    const epoch = workspaceEpoch.current
    const frame = requestAnimationFrame(() => {
      if (pendingWorkspaceFit.current !== epoch) return
      pendingWorkspaceFit.current = null
      if (nodes.length) void rf.fitView({ padding: 0.08, duration: 450 })
      else void rf.setViewport({ x: 0, y: 0, zoom: 1 }, { duration: 450 })
    })
    return () => cancelAnimationFrame(frame)
  }, [ready, nodes, rf])

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
      setPeek(null)
      const ns = latest.current.nodes
      const m = byId(ns)
      const items = target ? [m.get(target)].filter((n) => !!n) : ns.filter((n) => !n.parentId)
      if (!items.length) return
      let x0 = Infinity
      let y0 = Infinity
      let x1 = -Infinity
      let y1 = -Infinity
      for (const n of items) {
        const p = absPos(n, m)
        const s = sizeOf(n)
        x0 = Math.min(x0, p.x)
        y0 = Math.min(y0, p.y)
        x1 = Math.max(x1, p.x + s.w)
        y1 = Math.max(y1, p.y + s.h)
      }
      const box = canvasRef.current?.getBoundingClientRect()
      if (!target || !box) {
        rf.fitBounds({ x: x0, y: y0, width: x1 - x0, height: y1 - y0 }, { padding: 0.08, duration: 450 })
        return
      }
      // An opened group fills the view, with the connections outside it peeking in from the edges.
      const viewport = groupFitViewport(items[0], m, box)
      fitZoom.current.set(target, viewport.zoom)
      fitting.current = true
      setExitHint(null)
      const sequence = ++fitSequence.current
      void rf.setViewport(viewport, { duration: 450 }).then(() => {
        if (fitSequence.current === sequence) fitting.current = false
      })
    },
    [rf],
  )

  const selectOnly = useCallback(
    (id: string) => setNodes((ns) => ns.map((n) => (n.id === id ? { ...n, selected: true } : n.selected ? { ...n, selected: false } : n))),
    [],
  )

  const focusNode = useCallback(
    (id: string) => {
      const m = byId(latest.current.nodes)
      const n = m.get(id)
      if (!n) return
      selectOnly(id)
      const p = absPos(n, m)
      const s = sizeOf(n)
      rf.setCenter(p.x + s.w / 2, p.y + s.h / 2, { zoom: Math.max(rf.getZoom(), 0.9), duration: 450 })
    },
    [rf, selectOnly],
  )

  // Opening or closing a group fits it, unless a jump asked to land on one card.
  const fittedFor = useRef<string | null>(null)
  const pendingFocus = useRef<string | null>(null)
  useEffect(() => {
    if (fittedFor.current === root) return
    fittedFor.current = root
    setExitHint(null)
    const skipFit = skipNextFit.current
    skipNextFit.current = false
    if (skipFit) return
    const f = pendingFocus.current
    pendingFocus.current = null
    if (f) setTimeout(() => focusNode(f), 30)
    else fitTo(root)
  }, [root, fitTo, focusNode])

  /** Opens the group a card lives in and lands on the card. */
  const jumpTo = useCallback(
    (id: string) => {
      const n = byId(latest.current.nodes).get(id)
      if (!n) return
      const target = n.parentId ?? null
      setHover(null)
      if (target === root) {
        setPeek(null)
        setExitHint(null)
        focusNode(id)
      } else {
        pendingFocus.current = id
        openRoot(target)
      }
    },
    [root, focusNode, openRoot],
  )

  /** Moves nodes to new positions over a few frames so edges follow along. */
  const tweenTo = useCallback((target: AppNode[]) => {
    const from = byId(latest.current.nodes)
    const start = performance.now()
    const step = (now: number) => {
      const t = ease(Math.min(1, (now - start) / 380))
      setNodes(
        target.map((n) => {
          const f = from.get(n.id)
          if (!f || f.parentId !== n.parentId || t === 1) return n
          const lerp = (a: number, b: number) => a + (b - a) * t
          return {
            ...n,
            position: { x: lerp(f.position.x, n.position.x), y: lerp(f.position.y, n.position.y) },
            ...(isCluster(n) && f.width && n.width ? { width: lerp(f.width, n.width), height: lerp(f.height ?? 0, n.height ?? 0) } : {}),
          }
        }),
      )
      if (t < 1) requestAnimationFrame(step)
    }
    requestAnimationFrame(step)
  }, [])

  const map = useMemo(() => byId(nodes), [nodes])
  // Focus ends on its own if someone else removes the card.
  const focus = focusPick && map.has(focusPick) ? focusPick : null
  const rootWorkCount = useMemo(() => {
    if (!root) return 0
    const inside = descendants(root, nodes)
    return nodes.filter((n) => inside.has(n.id) && isTask(n) && !isNote(n)).length
  }, [root, nodes])
  const leaveRoot = useCallback(
    (atZoom = rf.getZoom()) => {
      if (!root) return
      const parent = map.get(root)?.parentId ?? null
      // Where you arrive becomes the parent's home zoom, so one gesture leaves one level.
      if (parent) fitZoom.current.set(parent, atZoom)
      skipNextFit.current = true
      setPeek(null)
      setExitHint(null)
      setRoot(parent)
    },
    [root, map, rf],
  )
  const onViewportMove = useCallback(
    (event: MouseEvent | TouchEvent | null, viewport: Viewport) => {
      const wasZoom = previousZoom.current
      previousZoom.current = viewport.zoom
      if (!event || fitting.current) return
      const userZoom =
        (event.type === 'wheel' && viewport.zoom !== wasZoom) || (event.type === 'touchmove' && 'touches' in event && event.touches.length > 1)
      if (peeking && !userZoom) {
        const group = map.get(root)
        const box = canvasRef.current?.getBoundingClientRect()
        if (group && box) {
          const p = absPos(group, map)
          const s = sizeOf(group)
          const x = p.x * viewport.zoom + viewport.x
          const y = p.y * viewport.zoom + viewport.y
          const w = s.w * viewport.zoom
          const h = s.h * viewport.zoom
          const visible = Math.max(0, Math.min(box.width, x + w) - Math.max(0, x)) * Math.max(0, Math.min(box.height, y + h) - Math.max(0, y))
          if (visible < w * h * PEEK_KEEP_VISIBLE) leaveRoot(viewport.zoom)
        }
        return
      }
      if (!userZoom || viewport.zoom === wasZoom) return
      const fit = root ? fitZoom.current.get(root) : undefined
      if (!root || fit === undefined) return
      const exit = exitRatio(rootWorkCount)
      const hint = exit + (1 - exit) * HINT_SPAN
      const progress = Math.min(1, Math.max(0, (hint - viewport.zoom / fit) / (hint - exit * PEEK_SPAN)))
      if (viewport.zoom < wasZoom && viewport.zoom < fit * exit * PEEK_SPAN) {
        leaveRoot(viewport.zoom)
      } else if (viewport.zoom <= fit * exit) {
        setPeek(root)
        setExitHint({ root, progress })
      } else {
        if (peeking) setPeek(null)
        setExitHint(viewport.zoom < fit * hint ? { root, progress } : null)
      }
    },
    [root, peeking, map, rootWorkCount, leaveRoot],
  )
  const work = useMemo(() => deriveWork(nodes, links), [nodes, links])

  // Which groups read as single bodies at this zoom, and which nodes that hides.
  const levelRoot = peeking ? (map.get(root)?.parentId ?? null) : root
  const inFocus = useCallback((id: string) => !!root && (id === root || ancestors(id, map).includes(root)), [root, map])
  const inView = useCallback((id: string) => !levelRoot || id === levelRoot || ancestors(id, map).includes(levelRoot), [levelRoot, map])
  const depthInView = (id: string) => {
    const chain = ancestors(id, map)
    return levelRoot ? chain.indexOf(levelRoot) : chain.length
  }
  const small = nodes
    // The open group stays open while peeking; only its surroundings fold.
    .filter((n) => isCluster(n) && n.id !== levelRoot && n.id !== root && inView(n.id) && depthInView(n.id) >= foldFrom)
    .map((n) => n.id)
  const smallSet = new Set(small)
  const collapsedKey = small.filter((id) => !ancestors(id, map).some((a) => smallSet.has(a))).join(',')
  const collapsed = useMemo(() => new Set(collapsedKey ? collapsedKey.split(',') : []), [collapsedKey])

  const view = useMemo(() => {
    const rep = (id: string): string | null => {
      if (!inView(id)) return null
      const outer = ancestors(id, map)
        .reverse()
        .find((a) => collapsed.has(a))
      return outer ?? id
    }
    const hidden = new Set(nodes.filter((n) => rep(n.id) !== n.id).map((n) => n.id))
    return { rep, hidden }
  }, [nodes, map, collapsed, inView])

  // With a group open, work outside it that links in or out is drawn along its sides.
  const ghosts = useMemo(() => {
    const out: GhostNode[] = []
    const rootNode = root ? map.get(root) : undefined
    if (!rootNode || peeking) return out
    const incoming: string[] = []
    const outgoing: string[] = []
    for (const l of links) {
      const a = inView(l.from)
      const b = inView(l.to)
      if (a && !b && !outgoing.includes(l.to)) outgoing.push(l.to)
      if (!a && b && !incoming.includes(l.from)) incoming.push(l.from)
    }
    const p = absPos(rootNode, map)
    const s = sizeOf(rootNode)
    const place = (ids: string[], side: 'in' | 'out') =>
      ids.forEach((id, i) => {
        const n = map.get(id)
        if (!n || !isTask(n)) return
        const parent = n.parentId ? map.get(n.parentId) : undefined
        out.push({
          id: `ghost:${side}:${id}`,
          type: 'ghost',
          position: {
            x: side === 'in' ? p.x - GHOST_W - GHOST_GAP : p.x + s.w + GHOST_GAP,
            y: p.y + s.h / 2 + (i - (ids.length - 1) / 2) * (GHOST_H + 18) - GHOST_H / 2,
          },
          width: GHOST_W,
          height: GHOST_H,
          // Ghosts are rebuilt every render, so declare their handles instead of waiting on a measure.
          handles: [
            side === 'in'
              ? { type: 'source', position: Position.Right, x: GHOST_W - 4, y: GHOST_H / 2 - 4, width: 8, height: 8 }
              : { type: 'target', position: Position.Left, x: -4, y: GHOST_H / 2 - 4, width: 8, height: 8 },
          ],
          selectable: false,
          draggable: false,
          connectable: false,
          zIndex: 5,
          data: {
            kind: 'ghost',
            taskId: id,
            label: n.data.label || 'Note',
            where: parent ? (parent.data as ClusterData).label : 'loose work',
            status: work.status.get(id) ?? 'ready',
            side,
          },
        })
      })
    place(incoming, 'in')
    place(outgoing, 'out')
    return out
  }, [root, peeking, map, links, inView, work])

  const viewNodes = useMemo<ViewNode[]>(
    () => [
      ...nodes.map((n) => ({
        ...n,
        hidden: view.hidden.has(n.id),
        className:
          [n.className, peeking && !inFocus(n.id) ? 'is-peek' : '', focus ? (n.id === focus ? 'is-focused' : 'is-unfocused') : '']
            .filter(Boolean)
            .join(' ') || undefined,
      })),
      ...(focus ? ghosts.map((g) => ({ ...g, className: 'is-unfocused' })) : ghosts),
    ],
    [nodes, view, ghosts, peeking, inFocus, focus],
  )

  const trace = useMemo(() => {
    const from = focus ? null : (pinned ?? hover)
    const h = from ? map.get(from) : undefined
    return h && isTask(h)
      ? traceFrom(
          h.id,
          work.preds,
          work.succs,
          nodes.filter(isTask).map((n) => n.id),
        )
      : null
  }, [focus, pinned, hover, map, work, nodes])

  const edges = useMemo(() => {
    const out: Edge[] = []
    const marker = (flow: Flow) => ({ type: MarkerType.ArrowClosed, width: 14, height: 14, color: `var(${EDGE_COLOR[flow]})` })
    const agg = new Map<string, { a: string; b: string; count: number; flow: Flow }>()
    for (const l of links) {
      let a = view.rep(l.from)
      let b = view.rep(l.to)
      if (root && !peeking && !a && b) a = `ghost:in:${l.from}`
      if (root && !peeking && a && !b && !a.startsWith('ghost:')) b = `ghost:out:${l.to}`
      if (!a || !b || a === b) continue
      const flow = work.flow.get(l.from) ?? 'live'
      const direct = (a === l.from || a.startsWith('ghost:')) && (b === l.to || b.startsWith('ghost:'))
      if (direct) {
        let cls = l.kind === 'related' ? 'e-rel' : `e-${flow}`
        if (trace) {
          const ra = trace.get(l.from)
          const rb = trace.get(l.to)
          const up = l.kind === 'blocks' && ra === 'up' && (rb === 'up' || rb === 'self')
          const down = l.kind === 'blocks' && (ra === 'down' || ra === 'self') && rb === 'down'
          cls += up ? ' tr-e-up' : down ? ' tr-e-down' : ' tr-e-dim'
        }
        if (peeking && !inFocus(a) && !inFocus(b)) cls += ' e-peek'
        out.push({ id: l.id, source: a, target: b, className: cls, markerEnd: l.kind === 'blocks' ? marker(flow) : undefined })
      } else if (l.kind === 'blocks') {
        const k = a + '>' + b
        const e = agg.get(k) ?? { a, b, count: 0, flow: 'held' }
        e.count++
        // A bundle moves if any of its links do.
        if (flow === 'live') e.flow = 'live'
        agg.set(k, e)
      }
    }
    for (const [k, e] of agg) {
      out.push({
        id: 'agg:' + k,
        source: e.a,
        target: e.b,
        className: `e-agg e-${e.flow}` + (peeking && !inFocus(e.a) && !inFocus(e.b) ? ' e-peek' : ''),
        selectable: false,
        label: e.count > 1 ? `${e.count} links` : undefined,
        markerEnd: marker(e.flow),
        style: { strokeWidth: Math.min(6, 1.5 + e.count * 0.8) },
      })
    }
    return out
  }, [links, view, work, trace, root, peeking, inFocus])

  // ---- Attention: hold ⌘ to see what needs you ----
  const [attending, setAttending] = useState(false)
  const pointer = useRef<{ x: number; y: number } | null>(null)
  const [cursor, setCursor] = useState<{ x: number; y: number } | null>(null)
  const [canvasSize, setCanvasSize] = useState({ w: 0, h: 0 })

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | undefined
    const stop = () => {
      clearTimeout(timer)
      setAttending(false)
    }
    // A short delay keeps ⌥ shortcuts from flashing the overlay.
    const down = (e: KeyboardEvent) => {
      if (e.key !== 'Alt') return stop()
      if (e.repeat) return
      timer = setTimeout(() => {
        const r = canvasRef.current?.getBoundingClientRect()
        if (r) setCanvasSize({ w: r.width, h: r.height })
        setCursor(pointer.current ?? (r ? { x: r.width / 2, y: r.height / 2 } : null))
        setAttending(true)
      }, ATTEND_DELAY_MS)
    }
    const up = (e: KeyboardEvent) => e.key === 'Alt' && stop()
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

  // ---- Selection box ----
  const [marquee, setMarquee] = useState<{ x: number; y: number; w: number; h: number } | null>(null)

  /**
   * Drags a selection box from empty canvas. Anything it touches is selected, but an open
   * group needs to be fully inside, since you drag across its body to reach what's in it.
   * ⇧ or ⌘ adds to the selection, and ⌘ draws the box in Pan too.
   */
  const startMarquee = (e: React.PointerEvent) => {
    const target = e.target as HTMLElement
    const box = canvasRef.current?.getBoundingClientRect()
    if (focus || e.button !== 0 || !box || !target.classList.contains('react-flow__pane')) return
    // In Select, a draggable pane means Space is held to pan.
    if (tool === 'select' ? target.classList.contains('draggable') : !(tool === 'hand' && e.metaKey)) return
    // Keeps the drag from also panning in Pan.
    e.preventDefault()
    const start = rf.screenToFlowPosition({ x: e.clientX, y: e.clientY })
    const base = e.shiftKey || e.metaKey ? nodes.filter((n) => n.selected).map((n) => n.id) : []
    const things = nodes
      .filter((n) => n.id !== root && !view.hidden.has(n.id) && inView(n.id))
      .map((n) => {
        const p = absPos(n, map)
        const s = sizeOf(n)
        return { id: n.id, x0: p.x, y0: p.y, x1: p.x + s.w, y1: p.y + s.h, whole: isCluster(n) && !collapsed.has(n.id) }
      })
    let moved = false
    let last = ''
    const move = (ev: PointerEvent) => {
      if (!moved && Math.hypot(ev.clientX - e.clientX, ev.clientY - e.clientY) < 3) return
      moved = true
      const end = rf.screenToFlowPosition({ x: ev.clientX, y: ev.clientY })
      const [x0, x1] = [Math.min(start.x, end.x), Math.max(start.x, end.x)]
      const [y0, y1] = [Math.min(start.y, end.y), Math.max(start.y, end.y)]
      const from = rf.flowToScreenPosition(start)
      setMarquee({
        x: Math.min(from.x, ev.clientX) - box.left,
        y: Math.min(from.y, ev.clientY) - box.top,
        w: Math.abs(ev.clientX - from.x),
        h: Math.abs(ev.clientY - from.y),
      })
      const covered = (t: (typeof things)[number]) => {
        const w = Math.min(t.x1, x1) - Math.max(t.x0, x0)
        const h = Math.min(t.y1, y1) - Math.max(t.y0, y0)
        const need = t.whole ? 1 : MARQUEE_REACH
        return w >= (t.x1 - t.x0) * need - 0.5 && h >= (t.y1 - t.y0) * need - 0.5
      }
      const hit = things.filter(covered).map((t) => t.id)
      const key = hit.join(',')
      if (key === last) return
      last = key
      const want = new Set([...base, ...hit])
      setNodes((ns) => ns.map((n) => (!!n.selected === want.has(n.id) ? n : { ...n, selected: want.has(n.id) })))
    }
    const end = () => {
      window.removeEventListener('pointermove', move)
      window.removeEventListener('pointerup', end)
      window.removeEventListener('pointercancel', end)
      setMarquee(null)
      if (!moved) return
      // The click that ends a drag would otherwise clear the selection.
      const swallow = (ev: MouseEvent) => ev.stopPropagation()
      window.addEventListener('click', swallow, { capture: true, once: true })
      setTimeout(() => window.removeEventListener('click', swallow, { capture: true }), 0)
    }
    window.addEventListener('pointermove', move)
    window.addEventListener('pointerup', end)
    window.addEventListener('pointercancel', end)
  }

  const trackPointer = (e: React.PointerEvent) => {
    const r = canvasRef.current?.getBoundingClientRect()
    if (!r) return
    pointer.current = { x: e.clientX - r.left, y: e.clientY - r.top }
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
      const m = marks.get(shown) ?? { ids: [] }
      m.ids.push(id)
      marks.set(shown, m)
    }
    return { marks, count: needs.length - elsewhere, elsewhere }
  }, [attending, needs, view])

  const transform = useStore((s) => (attending ? s.transform : null))
  // The focus view tracks the viewport only while open, so zooming elsewhere doesn't re-render the canvas.
  const focusTransform = useStore((s) => (focus ? s.transform : null))
  const attentionTargets = useMemo<AttentionTarget[]>(() => {
    if (!attention || !transform) return []
    const [panX, panY, zoom] = transform
    const out: AttentionTarget[] = []
    for (const [id, m] of attention.marks) {
      const n = map.get(id)
      if (!n) continue
      const p = absPos(n, map)
      const s = sizeOf(n)
      // A folded group's bubble rises from its center, so lines meet it there.
      const folded = isCluster(n)
      out.push({
        id,
        jump: m.ids[0],
        count: m.ids.length,
        label: m.ids.length === 1 ? (map.get(m.ids[0])?.data.label ?? '') : n.data.label,
        rect: folded
          ? { x: (p.x + s.w / 2) * zoom + panX, y: (p.y + s.h / 2) * zoom + panY, w: 0, h: 0 }
          : { x: p.x * zoom + panX, y: p.y * zoom + panY, w: s.w * zoom, h: s.h * zoom },
      })
    }
    return out
  }, [attention, map, transform])

  const derived = useMemo<Derived>(
    () => ({
      status: work.status,
      leverage: work.leverage,
      groups: work.groups,
      sources: work.sources,
      trace,
      collapsed,
      attention: attention?.marks ?? null,
    }),
    [work, trace, collapsed, attention],
  )

  const onNodesChange = useCallback(
    (changes: NodeChange<ViewNode>[]) => {
      let own = changes.filter((c) => !('id' in c) || !c.id.startsWith('ghost:')) as NodeChange<AppNode>[]
      if (plainClick.current) {
        const picks = own.filter((c) => c.type === 'select')
        own = own.filter((c) => c.type !== 'select')
        if (picks.length) afterClick(() => setNodes((ns) => applyNodeChanges(picks, ns)))
      }
      if (own.length) setNodes((ns) => applyNodeChanges(own, ns))
    },
    [afterClick],
  )

  // ---- Focus on one card ----

  const focusOn = useCallback(
    (id: string) => {
      const m = byId(latest.current.nodes)
      const n = m.get(id)
      const box = canvasRef.current?.getBoundingClientRect()
      if (!n || !isTask(n) || !box) return
      if (!focus || !focusEntry.current) focusEntry.current = { viewport: rf.getViewport(), moved: false }
      else if (id !== focus) focusEntry.current.moved = true
      if (peeking && !inFocus(id)) leaveRoot()
      // Work outside the open level opens its own group underneath, so leaving focus lands there.
      if (!inView(id)) {
        const parent = n.parentId ? m.get(n.parentId) : undefined
        if (parent) fitZoom.current.set(parent.id, groupFitViewport(parent, m, box).zoom)
        skipNextFit.current = true
        setPeek(null)
        setExitHint(null)
        setRoot(parent?.id ?? null)
        focusEntry.current.moved = true
      }
      setHover(null)
      setPinned(null)
      setNodes((ns) => (ns.some((x) => x.selected) ? ns.map((x) => (x.selected ? { ...x, selected: false } : x)) : ns))
      setFocus(id)
      void rf.setViewport(focusViewport(n, m, box), FOCUS_MOVE)
    },
    [rf, focus, peeking, inFocus, inView, leaveRoot],
  )

  const exitFocus = useCallback(() => {
    const entry = focusEntry.current
    const m = byId(latest.current.nodes)
    const n = focus ? m.get(focus) : undefined
    setFocus(null)
    focusEntry.current = null
    if (!entry) return
    if (!entry.moved || !n) {
      void rf.setViewport(entry.viewport, FOCUS_MOVE)
      return
    }
    const p = absPos(n, m)
    const s = sizeOf(n)
    const zoom = (root ? fitZoom.current.get(root) : undefined) ?? entry.viewport.zoom
    void rf.setCenter(p.x + s.w / 2, p.y + s.h / 2, { zoom, ...FOCUS_MOVE })
  }, [focus, root, rf])

  const focusItems = useMemo(() => {
    if (!focus) return null
    const item = (id: string, related: boolean): FocusItem | null => {
      const n = map.get(id)
      if (!n || !isTask(n)) return null
      const parent = n.parentId ? map.get(n.parentId) : undefined
      const status = work.status.get(id) ?? 'ready'
      return {
        id,
        label: n.data.label || (isNote(n) ? 'Empty note' : 'Untitled'),
        tag: isNote(n) ? 'Note' : getTaskTag(n.data),
        status,
        where: parent ? (parent.data as ClusterData).label : 'Loose work',
        related,
        flow: work.flow.get(id) ?? 'live',
      }
    }
    const incoming: FocusItem[] = []
    const outgoing: FocusItem[] = []
    for (const l of links) {
      if (l.to === focus && !incoming.some((i) => i.id === l.from)) {
        const i = item(l.from, l.kind === 'related')
        if (i) incoming.push(i)
      }
      if (l.from === focus && !outgoing.some((i) => i.id === l.to)) {
        const o = item(l.to, l.kind === 'related')
        // A link reads by its source, and here the source is the focused card.
        if (o) outgoing.push({ ...o, flow: work.flow.get(focus) ?? 'live' })
      }
    }
    const settled = (i: FocusItem) => (i.status === 'done' || i.status === 'deferred' ? 1 : 0)
    return { incoming: incoming.sort((a, b) => settled(a) - settled(b)), outgoing: outgoing.sort((a, b) => settled(a) - settled(b)) }
  }, [focus, links, map, work])

  const onDragStop = useCallback(() => setNodes((ns) => normalize(ns)), [])
  const onConnect = useCallback((c: Connection) => {
    if (!c.source || !c.target || c.source === c.target) return
    setLinks((ls) =>
      ls.some((l) => l.from === c.source && l.to === c.target)
        ? ls
        : [...ls, { id: `${c.source}>${c.target}`, from: c.source, to: c.target, kind: 'blocks' }],
    )
  }, [])

  const selected = nodes.filter((n) => n.selected && !view.hidden.has(n.id))

  // Reported again on focus so the page the person is using wins over other open pages.
  const focusReportKey = JSON.stringify({ open: root, selected: selected.map((n) => n.id) } satisfies FocusReport)
  useEffect(() => {
    if (!ready) return
    const workspaceName = workspace.current
    const report = () => reportFocus(JSON.parse(focusReportKey) as FocusReport, workspaceName)
    const t = setTimeout(report, 150)
    window.addEventListener('focus', report)
    window.addEventListener('pageshow', report)
    return () => {
      clearTimeout(t)
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
    const visibleSel = nodes.map((n) => (n.selected && view.hidden.has(n.id) ? { ...n, selected: false } : n))
    const r = groupSelection(visibleSel)
    if (!r) return
    setNodes(r.nodes)
    setEditing(r.groupId)
  }, [nodes, view])

  const doUngroup = useCallback(
    (ids?: string[]) => {
      const targets = ids ?? selected.filter(isCluster).map((n) => n.id)
      if (!targets.length) return
      if (root && targets.includes(root)) openRoot(map.get(root)?.parentId ?? null)
      setNodes(ungroup(nodes, targets))
    },
    [nodes, selected, root, map, openRoot],
  )

  const actions = useMemo(
    () => ({
      reflow: (gid: string) => {
        const { nodes: ns, links: ls } = latest.current
        reflow(ns, ls, gid).then(tweenTo)
      },
      open: (gid: string) => {
        openRoot(gid)
        setHover(null)
      },
    }),
    [tweenTo, openRoot],
  )

  const updateData = useCallback(
    (id: string, patch: Partial<TaskData> | Partial<ClusterData>) =>
      setNodes((ns) => ns.map((n) => (n.id === id ? ({ ...n, data: { ...n.data, ...patch } } as AppNode) : n))),
    [],
  )

  // ---- Notes and links ----

  /** Adds a note with its top-left at `at` (flow coordinates), optionally spliced into links. */
  const addNote = useCallback(
    (at: { x: number; y: number }, opts: { parent?: string | null; from?: string; to?: string; replace?: string } = {}) => {
      const { nodes: ns, links: ls } = latest.current
      const m = byId(ns)
      const parent = opts.parent === undefined ? root : opts.parent
      const parentNode = parent ? m.get(parent) : undefined
      const origin = parentNode ? absPos(parentNode, m) : { x: 0, y: 0 }
      const id = newId('note')
      const note: AppNode = {
        id,
        type: 'task',
        parentId: parentNode?.id,
        position: { x: at.x - origin.x, y: at.y - origin.y },
        data: { kind: 'task', label: '', itemKind: 'note', status: 'todo' },
        selected: true,
      }
      const kind = ls.find((l) => l.id === opts.replace)?.kind ?? 'blocks'
      const next = ls.filter((l) => l.id !== opts.replace)
      if (opts.from) next.push({ id: `${opts.from}>${id}`, from: opts.from, to: id, kind })
      if (opts.to) next.push({ id: `${id}>${opts.to}`, from: id, to: opts.to, kind })
      setNodes(normalize([...ns.map((n) => (n.selected ? { ...n, selected: false } : n)), note]))
      setLinks(next)
      setEditing(id)
    },
    [root],
  )

  const viewportCenter = useCallback(() => {
    const r = canvasRef.current?.getBoundingClientRect()
    if (!r) return { x: 0, y: 0 }
    const c = rf.screenToFlowPosition({ x: r.left + r.width / 2, y: r.top + r.height / 2 })
    return { x: c.x - TASK_W / 2, y: c.y - TASK_H / 2 }
  }, [rf])

  /** The innermost visible card or group under a canvas point that `accept` allows. */
  const nodeAt = useCallback(
    (point: { x: number; y: number }, accept: (n: AppNode) => boolean) => {
      let found: string | null = null
      let depth = -1
      for (const n of nodes) {
        if (view.hidden.has(n.id) || !inView(n.id) || !accept(n)) continue
        const p = absPos(n, map)
        const s = sizeOf(n)
        const d = ancestors(n.id, map).length
        if (point.x >= p.x && point.x <= p.x + s.w && point.y >= p.y && point.y <= p.y + s.h && d > depth) {
          found = n.id
          depth = d
        }
      }
      return found
    },
    [nodes, map, view, inView],
  )

  /** Drops a note centered on a click, inside the innermost open group under it. */
  const placeComment = useCallback(
    (e: React.MouseEvent) => {
      const point = rf.screenToFlowPosition({ x: e.clientX, y: e.clientY })
      const parent = nodeAt(point, (n) => isCluster(n) && !collapsed.has(n.id)) ?? levelRoot
      if (peeking && !(parent && inFocus(parent))) leaveRoot()
      addNote({ x: point.x - TASK_W / 2, y: point.y - TASK_H / 2 }, { parent })
      setTool('select')
    },
    [rf, nodeAt, collapsed, levelRoot, peeking, inFocus, leaveRoot, addNote],
  )

  // ---- Stickers ----

  /** Where a sticker dropped at a canvas point sits: on the card or group under it, or loose. */
  const anchorAt = useCallback(
    (point: { x: number; y: number }) => {
      const on = nodeAt(point, () => true)
      const n = on ? map.get(on) : undefined
      if (!n) return { x: Math.round(point.x), y: Math.round(point.y) }
      const p = absPos(n, map)
      return { x: Math.round(point.x - p.x), y: Math.round(point.y - p.y), on: n.id }
    },
    [nodeAt, map],
  )

  const stamp = useCallback(
    (e: React.MouseEvent) => {
      const id = newId('sticker')
      const at = anchorAt(rf.screenToFlowPosition({ x: e.clientX, y: e.clientY }))
      setStickers((ss) => [...ss, { id, kind: sticker, tilt: Math.round((Math.random() * 2 - 1) * STICKER_TILT), ...at }])
      setFresh((f) => new Set(f).add(id))
      setTimeout(
        () =>
          setFresh((f) => {
            const next = new Set(f)
            next.delete(id)
            return next
          }),
        STICKER_FRESH_MS,
      )
    },
    [rf, sticker, anchorAt],
  )

  const settleStickers = useCallback(
    (moves: StickerMove[]) => {
      const landed = new Map(moves.map((m) => [m.id, m]))
      setStickers((ss) =>
        ss.map((s) => {
          const at = landed.get(s.id)
          return at ? { id: s.id, kind: s.kind, tilt: s.tilt, ...anchorAt(at) } : s
        }),
      )
    },
    [anchorAt],
  )

  /** Every group frame on screen, which stickers bounce inside and off of. */
  const stickerBounds = useMemo<StickerBounds[]>(() => {
    const shown = nodes.filter((n) => isCluster(n) && !view.hidden.has(n.id) && inView(n.id))
    const ids = new Set(shown.map((n) => n.id))
    return shown.map((n) => {
      const p = absPos(n, map)
      const s = sizeOf(n)
      const chain = ancestors(n.id, map)
      return { id: n.id, x0: p.x, y0: p.y, x1: p.x + s.w, y1: p.y + s.h, parent: chain.find((a) => ids.has(a)) ?? null, depth: chain.length }
    })
  }, [nodes, map, view, inView])

  const placedStickers = useMemo<PlacedSticker[]>(
    () =>
      stickers.flatMap((s) => {
        if (!s.on) return [{ ...s, fresh: fresh.has(s.id) }]
        const n = map.get(s.on)
        if (!n || view.hidden.has(n.id)) return []
        const p = absPos(n, map)
        return [{ ...s, x: p.x + s.x, y: p.y + s.y, fresh: fresh.has(s.id) }]
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
    const r = canvasRef.current?.getBoundingClientRect()
    const p = pointer.current
    if (r) setWheel({ x: r.left + (p?.x ?? r.width / 2), y: r.top + (p?.y ?? r.height / 2), held: true })
  }, [])

  const assignSlot = useCallback((slot: number, emoji: string | null) => setLoadout((l) => l.map((s, i) => (i === slot ? emoji : s))), [])

  const pickSticker = useCallback((id: string) => {
    setSticker(id)
    setTool('sticker')
    setWheel(null)
  }, [])

  const insertNoteOnLink = (linkId: string) => {
    const l = links.find((x) => x.id === linkId)
    const a = l && map.get(l.from)
    const b = l && map.get(l.to)
    if (!l || !a || !b) return
    const pa = absPos(a, map)
    const pb = absPos(b, map)
    const chainB = [b.parentId, ...ancestors(b.id, map)]
    const parent = [a.parentId, ...ancestors(a.id, map)].find((p) => p && chainB.includes(p)) ?? null
    addNote({ x: (pa.x + pb.x) / 2, y: (pa.y + pb.y) / 2 + TASK_H }, { parent, from: l.from, to: l.to, replace: l.id })
  }

  /** Removes a note and reconnects whatever ran through it. */
  const deleteNote = (id: string) => {
    setLinks((ls) => {
      const ins = ls.filter((l) => l.to === id)
      const outs = ls.filter((l) => l.from === id)
      const next = ls.filter((l) => l.from !== id && l.to !== id)
      for (const i of ins)
        for (const o of outs)
          if (!next.some((l) => l.from === i.from && l.to === o.to))
            next.push({ id: `${i.from}>${o.to}`, from: i.from, to: o.to, kind: i.kind === 'blocks' && o.kind === 'blocks' ? 'blocks' : 'related' })
      return next
    })
    setNodes((ns) => normalize(ns.filter((n) => n.id !== id)))
  }

  const removeLink = (id: string) => setLinks((ls) => ls.filter((l) => l.id !== id))
  const flipLink = (id: string) => setLinks((ls) => ls.map((l) => (l.id === id ? { ...l, kind: l.kind === 'blocks' ? 'related' : 'blocks' } : l)))

  const tidy = () => reflow(nodes, links, root ?? undefined).then(tweenTo)
  const reset = () => {
    openRoot(null)
    seeded().then((s) => {
      setNodes(s.nodes)
      setLinks(s.links)
      setStickers([])
      setTimeout(() => fitTo(null), 40)
    })
  }

  // ---- Context menu ----

  const openMenu = (e: MouseEvent | React.MouseEvent, target: Menu['target']) => {
    e.preventDefault()
    setMenu({ x: e.clientX, y: e.clientY, flow: rf.screenToFlowPosition({ x: e.clientX, y: e.clientY }), target })
  }

  const menuItems = (m: Menu): MenuItem[] => {
    const t = m.target
    if (t.kind === 'sticker') return [{ label: 'Remove sticker', danger: true, run: () => setStickers((ss) => ss.filter((s) => s.id !== t.id)) }]
    if (t.kind === 'edge') {
      const l = links.find((x) => x.id === t.id)
      if (!l) return []
      return [
        { label: 'Insert a note here', run: () => insertNoteOnLink(l.id) },
        { label: l.kind === 'blocks' ? 'Make it a related link' : 'Make it a blocking link', run: () => flipLink(l.id) },
        'divider',
        { label: 'Remove link', danger: true, run: () => removeLink(l.id) },
      ]
    }
    if (t.kind === 'node') {
      if (t.id.startsWith('ghost:')) {
        const taskId = t.id.split(':')[2]
        return [{ label: 'Jump to it', run: () => jumpTo(taskId) }]
      }
      const n = map.get(t.id)
      if (!n) return []
      const many: MenuItem[] = selected.length > 1 ? [{ label: `Group ${selected.length} selected`, hint: '⌘G', run: doGroup }, 'divider'] : []
      if (isCluster(n))
        return [
          ...many,
          { label: 'Open', hint: '↵', run: () => actions.open(n.id) },
          { label: 'Rename', run: () => (selectOnly(n.id), setEditing(n.id)) },
          { label: 'Reflow', run: () => actions.reflow(n.id) },
          { label: 'Ungroup', hint: '⇧⌘G', run: () => doUngroup([n.id]) },
        ]
      const p = absPos(n, map)
      const after = { x: p.x + TASK_W + 48, y: p.y + TASK_H + 24 }
      if (isNote(n))
        return [
          ...many,
          { label: 'Edit note', run: () => (selectOnly(n.id), setEditing(n.id)) },
          { label: 'Turn into a work item', run: () => updateData(n.id, { itemKind: 'step', status: 'todo' }) },
          'divider',
          { label: 'Delete note', danger: true, run: () => deleteNote(n.id) },
        ]
      const data = n.data as TaskData
      const url = getTaskUrl(data, githubOwner)
      return [
        ...many,
        ...(url ? [{ label: `Open ${getTaskTag(data)}`, hint: '↗', run: () => window.open(url, '_blank', 'noreferrer') }] : []),
        data.status === 'done'
          ? { label: 'Mark not done', run: () => updateData(n.id, { status: 'todo' }) }
          : { label: 'Mark done', run: () => updateData(n.id, { status: 'done' }) },
        { label: 'Add a note after this', run: () => addNote(after, { parent: n.parentId ?? null, from: n.id }) },
        ...(n.parentId !== root ? [{ label: 'Open its group', run: () => jumpTo(n.id) }] : []),
      ]
    }
    return [
      { label: 'Add a note here', hint: 'N', run: () => addNote(m.flow) },
      ...(selected.length > 1 ? [{ label: `Group ${selected.length} selected`, hint: '⌘G', run: doGroup }] : []),
      'divider',
      { label: root ? 'Tidy this group' : 'Tidy canvas', run: tidy },
      { label: 'Fit to screen', hint: '⇧1', run: () => fitTo(root) },
      ...(root ? [{ label: 'Go up a level', hint: 'Esc', run: () => (peeking ? leaveRoot() : openRoot(map.get(root)?.parentId ?? null)) }] : []),
    ]
  }

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement).closest('input, textarea, select, [contenteditable="true"]')) return
      if ((e.metaKey || e.ctrlKey) && !e.shiftKey && !e.altKey && e.key.toLowerCase() === 'k') {
        e.preventDefault()
        setPaletteOpen(true)
        return
      }
      if (paletteOpen) return
      if (focus) {
        if (e.key === 'Escape') exitFocus()
        return
      }
      if (e.metaKey && e.key.toLowerCase() === 'g') {
        e.preventDefault()
        if (e.shiftKey) doUngroup()
        else doGroup()
      } else if (e.key === 'Enter' && selected.length === 1 && isCluster(selected[0])) {
        actions.open(selected[0].id)
      } else if (e.key === 'Escape') {
        if (tool !== 'select') setTool('select')
        else if (peeking) leaveRoot()
        else if (pinned) setPinned(null)
        else if (root) openRoot(map.get(root)?.parentId ?? null)
        else setNodes((ns) => ns.map((n) => (n.selected ? { ...n, selected: false } : n)))
      } else if (e.shiftKey && e.code === 'Digit1') {
        fitTo(root)
      } else if (!e.metaKey && !e.ctrlKey && e.key.toLowerCase() === 'n') {
        e.preventDefault()
        addNote(viewportCenter())
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [
    doGroup,
    doUngroup,
    selected,
    actions,
    root,
    peeking,
    map,
    fitTo,
    addNote,
    viewportCenter,
    pinned,
    leaveRoot,
    openRoot,
    tool,
    paletteOpen,
    focus,
    exitFocus,
  ])

  const crumbs = root ? [...ancestors(root, map).reverse(), root] : []
  const one = selected.length === 1 ? selected[0] : null
  const focused = focus ? map.get(focus) : undefined
  const focusPos = focused && absPos(focused, map)
  const focusSize = focused && sizeOf(focused)
  const readyTotal = [...work.status.values()].filter((s) => s === 'ready').length

  const toggleSidebar = (v: boolean) => {
    setSidebar(v)
    writeFlag(SIDEBAR_KEY, v)
  }

  const chooseColorMode = (mode: ColorMode) => {
    setColorMode(mode)
    if (mode === 'system') document.documentElement.removeAttribute('data-theme')
    else document.documentElement.dataset.theme = mode
    writeColorMode(mode)
  }

  return (
    <DerivedContext.Provider value={derived}>
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
              colorMode={colorMode}
              chooseColorMode={chooseColorMode}
            />
          )}
          <div
            className={`canvas tool-${tool}${attending ? ' is-attending' : ''}${focus ? ' is-focus' : ''}${still ? ' is-still' : ''}`}
            style={tool === 'sticker' ? ({ '--sticker-cursor': stickerCursor(sticker) } as CSSProperties) : undefined}
            ref={canvasRef}
            onPointerDown={startMarquee}
            onPointerMove={trackPointer}
            onClickCapture={claimNodeClick}
          >
            {ready && (
              <ReactFlow<ViewNode, Edge>
                fitView
                fitViewOptions={{ padding: 0.12 }}
                nodes={viewNodes}
                edges={edges}
                nodeTypes={nodeTypes}
                onNodesChange={onNodesChange}
                onMove={onViewportMove}
                onNodeDragStop={onDragStop}
                onConnect={onConnect}
                onNodeMouseEnter={(_, n) => !focus && setHover(n.type === 'task' ? n.id : n.type === 'ghost' ? n.data.taskId : null)}
                onNodeMouseLeave={() => setHover(null)}
                onNodeClick={(e, n) => {
                  if (tool === 'sticker') return stamp(e)
                  if (focus) return
                  setPinned(null)
                  if (n.type === 'ghost') {
                    afterClick(() => jumpTo(n.data.taskId))
                    return
                  }
                  if (peeking && !inFocus(n.id)) afterClick(() => leaveRoot())
                }}
                onNodeDoubleClick={(e, n) => {
                  cancelClick()
                  if (tool === 'sticker' || focus) return
                  if (e.shiftKey && n.type === 'task') {
                    if (isNote(n)) setEditing(n.id)
                    else setPinned(n.id)
                    return
                  }
                  if (n.type === 'task' || n.type === 'ghost') return focusOn(n.type === 'ghost' ? n.data.taskId : n.id)
                  if (n.type !== 'cluster') return
                  if (peeking && !inFocus(n.id)) leaveRoot()
                  actions.open(n.id)
                }}
                onNodeDragStart={(_, n) => {
                  if (peeking && !inFocus(n.id)) leaveRoot()
                }}
                onPaneClick={(e) => {
                  if (focus) return exitFocus()
                  setPinned(null)
                  if (tool === 'comment') placeComment(e)
                  else if (tool === 'sticker') stamp(e)
                }}
                onEdgeClick={() => setPinned(null)}
                onPaneContextMenu={(e) => (focus ? e.preventDefault() : openMenu(e, { kind: 'pane' }))}
                onNodeContextMenu={(e, n) => {
                  if (focus) return e.preventDefault()
                  if (peeking && !inFocus(n.id)) leaveRoot()
                  if (n.type !== 'ghost' && !n.selected) selectOnly(n.id)
                  openMenu(e, { kind: 'node', id: n.id })
                }}
                onSelectionContextMenu={(e, ns) => openMenu(e, { kind: 'node', id: ns[0]?.id ?? '' })}
                onEdgeContextMenu={(e, edge) => !edge.id.startsWith('agg:') && openMenu(e, { kind: 'edge', id: edge.id })}
                panOnDrag={focus ? false : tool === 'hand' ? [0, 1] : [1]}
                selectionKeyCode={null}
                selectionOnDrag={false}
                nodesDraggable={!focus && (tool === 'select' || tool === 'comment')}
                nodesConnectable={!focus && (tool === 'select' || tool === 'comment')}
                elementsSelectable={!focus && tool !== 'sticker'}
                panOnScroll={!focus}
                zoomOnScroll={false}
                zoomOnPinch={!focus}
                multiSelectionKeyCode={['Meta', 'Shift']}
                deleteKeyCode={null}
                zoomOnDoubleClick={false}
                minZoom={0.06}
                maxZoom={2}
                colorMode={colorMode}
              >
                <StickerLayer
                  stickers={placedStickers}
                  interactive={!focus && tool === 'select'}
                  bounds={stickerBounds}
                  settle={settleStickers}
                  menu={(e, id) => openMenu(e, { kind: 'sticker', id })}
                />
                {marquee && (
                  <div
                    className="react-flow__selection marquee"
                    style={{ transform: `translate(${marquee.x}px, ${marquee.y}px)`, width: marquee.w, height: marquee.h }}
                  />
                )}
                <Background variant={BackgroundVariant.Dots} gap={24} size={1.3} color="var(--dots)" />
                <Controls showInteractive={false} />
                {mergeNotice !== null && (
                  <Panel
                    position="bottom-left"
                    style={{ bottom: 100, margin: 15, padding: '8px 10px', maxWidth: 300, pointerEvents: 'none' }}
                    role="status"
                  >
                    Merged with changes made elsewhere; kept yours for {mergeNotice} {mergeNotice === 1 ? 'field' : 'fields'}
                  </Panel>
                )}
                <MiniMap
                  pannable
                  zoomable
                  nodeClassName={(n) =>
                    n.type === 'cluster' ? 'mm-cluster' : n.type === 'ghost' ? 'mm-ghost' : 'mm-' + (work.status.get(n.id) ?? 'ready')
                  }
                />

                <Panel position="top-left" className="panel crumbs">
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
                  <span className="crumb-actions">
                    <button type="button" className="btn" onClick={() => setPaletteOpen(true)}>
                      Search <kbd>⌘K</kbd>
                    </button>
                    <button type="button" className="btn" onClick={() => addNote(viewportCenter())}>
                      Add note
                    </button>
                    <button type="button" className="btn" onClick={tidy}>
                      Tidy {root ? 'group' : 'canvas'}
                    </button>
                    <button type="button" className="btn" onClick={reset}>
                      Reset to seed
                    </button>
                    {syncStatus && (
                      <button
                        type="button"
                        className="sync-status"
                        title={syncStatus.message ?? 'Sync with GitHub now'}
                        onClick={() => void requestSync(true).then((status) => status && setSyncStatus(status))}
                      >
                        {syncStatus.state === 'running'
                          ? 'Syncing…'
                          : syncStatus.state === 'error'
                            ? 'Sync failed'
                            : syncStatus.state === 'unavailable'
                              ? 'Sync unavailable'
                              : syncStatus.lastRun
                                ? `Synced ${relativeTime(syncStatus.lastRun, clock)}`
                                : 'Sync now'}
                      </button>
                    )}
                  </span>
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
                        work={work}
                        map={map}
                        github={github}
                        githubOwner={githubOwner}
                        update={updateData}
                        jumpTo={jumpTo}
                      />
                    ) : (
                      <div className="insp" key={one.id}>
                        <label htmlFor="g-label">Group name</label>
                        <input
                          id="g-label"
                          value={(one.data as ClusterData).label}
                          autoFocus={editing === one.id}
                          onFocus={(e) => editing === one.id && e.target.select()}
                          onBlur={() => setEditing(null)}
                          onKeyDown={(e) => e.key === 'Enter' && (e.target as HTMLInputElement).blur()}
                          onChange={(e) => updateData(one.id, { label: e.target.value })}
                        />
                        {(one.data as ClusterData).blurb && <p className="blurb">{(one.data as ClusterData).blurb}</p>}
                        <GroupFacts stats={work.groups.get(one.id)} />
                        <div className="row">
                          <button type="button" className="btn primary" onClick={() => actions.open(one.id)}>
                            Open
                          </button>
                          <button type="button" className="btn" onClick={() => actions.reflow(one.id)}>
                            Reflow
                          </button>
                          <button type="button" className="btn" onClick={() => doUngroup([one.id])}>
                            Ungroup <kbd>⇧⌘G</kbd>
                          </button>
                        </div>
                      </div>
                    )}
                  </Panel>
                )}

                <Panel position="bottom-center" className="dock">
                  {root && exitHint?.root === root && (
                    <div className="zoom-exit-hint">
                      <span>Keep zooming out to leave {(map.get(root)?.data as ClusterData | undefined)?.label}</span>
                      <div className="zoom-exit-track">
                        <div className="zoom-exit-fill" style={{ width: `${exitHint.progress * 100}%` }} />
                      </div>
                    </div>
                  )}
                  <Toolbar tool={tool} sticker={sticker} setTool={chooseTool} />
                  <div className="panel help">
                    {showHelp ? (
                      <>
                        V select · H pan · C comment · hold S for stickers · drag to select · middle-drag, Space-drag, or scroll to pan · pinch or
                        ⌘-scroll to zoom · ⌘ or ⇧ click to add · right-click for actions · ⌘G group · ⇧⌘G ungroup · double-click a group to open ·
                        double-click a card to focus · ⇧ double-click to hold its trace or edit a note · Esc to go up · N note · ⇧1 fit · drag from a
                        card's edge to link{' '}
                        <button type="button" className="link" onClick={() => setShowHelp(false)}>
                          Hide
                        </button>
                      </>
                    ) : (
                      <button type="button" className="link" onClick={() => setShowHelp(true)}>
                        Shortcuts
                      </button>
                    )}
                  </div>
                </Panel>
              </ReactFlow>
            )}
            {attending && cursor && (
              <AttentionOverlay
                targets={attentionTargets}
                count={attention?.count ?? 0}
                elsewhere={attention?.elsewhere ?? 0}
                cursor={cursor}
                width={canvasSize.w}
                height={canvasSize.h}
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
                  w: focusSize.w * focusTransform[2],
                  h: focusSize.h * focusTransform[2],
                }}
                sideWidth={FOCUS_SIDE_W}
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
                    githubOwner={githubOwner}
                    update={updateData}
                    jumpTo={focusOn}
                    connections={false}
                  />
                )}
              </FocusView>
            )}
            {!ready && <div className="loading">Laying out…</div>}
            {menu && <ContextMenu x={menu.x} y={menu.y} items={menuItems(menu)} close={() => setMenu(null)} />}
            {wheel && (
              <StickerWheel
                at={wheel}
                held={wheel.held}
                current={sticker}
                loadout={loadout}
                pick={pickSticker}
                assign={assignSlot}
                close={() => setWheel(null)}
              />
            )}
          </div>
          {paletteOpen && (
            <Palette
              nodes={nodes}
              jumpTo={jumpTo}
              open={actions.open}
              close={() => setPaletteOpen(false)}
              commands={(['light', 'dark', 'system'] as const).map((mode) => ({
                label: `Color mode: ${mode[0].toUpperCase()}${mode.slice(1)}`,
                run: () => chooseColorMode(mode),
              }))}
            />
          )}
        </div>
      </ActionsContext.Provider>
    </DerivedContext.Provider>
  )
}

function GroupFacts({ stats }: { stats?: GroupStats }) {
  if (!stats) return null
  return (
    <p className="facts">
      {stats.done}/{stats.total} done · {stats.ready} ready · {stats.blocked} blocked
      {stats.outside > 0 && <> · unblocks {stats.outside} outside</>}
    </p>
  )
}

function NoteInspector({
  node,
  focus,
  doneEditing,
  update,
  remove,
}: {
  node: AppNode
  focus: boolean
  doneEditing: () => void
  update: (id: string, patch: Partial<TaskData>) => void
  remove: () => void
}) {
  const data = node.data as TaskData
  return (
    <div className="insp">
      <label htmlFor="n-text">Note</label>
      <textarea
        id="n-text"
        rows={5}
        value={data.label}
        autoFocus={focus}
        placeholder="A detail to remember, or a plan that might become a pull request"
        onBlur={doneEditing}
        onChange={(e) => update(node.id, { label: e.target.value })}
      />
      <p className="facts">Notes pass blocking through but never count as work.</p>
      <div className="row">
        <button type="button" className="btn" onClick={() => update(node.id, { itemKind: 'step', status: 'todo' })}>
          Turn into a work item
        </button>
        <button type="button" className="btn danger" onClick={remove}>
          Delete
        </button>
      </div>
    </div>
  )
}

function TaskInspector({
  node,
  work,
  map,
  github,
  githubOwner,
  update,
  jumpTo,
  connections = true,
}: {
  node: AppNode
  work: ReturnType<typeof deriveWork>
  map: Map<string, AppNode>
  github: GithubSnapshot | null
  githubOwner: string
  update: (id: string, patch: Partial<TaskData>) => void
  jumpTo: (id: string) => void
  /** Lists what the card waits on and unblocks. */
  connections?: boolean
}) {
  const data = node.data as TaskData
  const st = work.status.get(node.id) ?? 'ready'
  const lev = work.leverage.get(node.id) ?? 0
  const url = getTaskUrl(data, githubOwner)
  const linked = new Set(
    [...map.values()]
      .filter(isTask)
      .filter((n) => n.data.repo && n.data.pr)
      .map((n) => `${n.data.repo}#${n.data.pr}`),
  )
  const suggestions = data.pr
    ? []
    : (github?.unplaced ?? [])
        .filter((pr) => !linked.has(`${pr.repo}#${pr.number}`))
        .flatMap((pr) => pr.matches.filter((match) => match.id === node.id).map((match) => ({ pr, score: match.score })))
        .sort((a, b) => b.score - a.score)
  const list = (ids: string[]) =>
    ids.length ? (
      <ul>
        {ids.map((id) => {
          const other = map.get(id)
          const parent = other?.parentId ? map.get(other.parentId) : undefined
          return (
            <li key={id}>
              <button type="button" className="link" onClick={() => jumpTo(id)}>
                {(other?.data as TaskData | undefined)?.label || 'Note'} <span>({STATUS_LABEL[work.status.get(id) ?? 'ready']})</span>
              </button>
              {parent && parent.id !== node.parentId && <span className="link-where">in {(parent.data as ClusterData).label}</span>}
            </li>
          )
        })}
      </ul>
    ) : (
      <p className="facts">Nothing</p>
    )
  return (
    <div className="insp">
      <label htmlFor="t-label">Title</label>
      <input id="t-label" value={data.label} onChange={(e) => update(node.id, { label: e.target.value })} />
      {url && (
        <a className="pr-link" href={url} target="_blank" rel="noreferrer">
          Open {getTaskTag(data)} ↗
        </a>
      )}
      {data.github && (
        <div className="github-details">
          <p className="facts">{githubSummary(data.github)}</p>
          <p className="facts">
            {data.github.checks && (
              <>
                <span className={`check-dot check-${data.github.checks.toLowerCase()}`} />
                {data.github.checks === 'SUCCESS'
                  ? 'Checks passing'
                  : ['FAILURE', 'ERROR'].includes(data.github.checks)
                    ? 'Checks failing'
                    : 'Checks pending'}{' '}
                ·{' '}
              </>
            )}
            {typeof data.github.additions === 'number' && (
              <>
                +{data.github.additions} −{data.github.deletions} · updated {relativeTime(data.github.updatedAt)}
              </>
            )}
          </p>
          {data.github.author && !data.github.mine && <p className="facts">By {data.github.author}</p>}
          {data.github.requestedFromYou && <p className="facts review-requested">Your review is requested</p>}
        </div>
      )}
      <div className="grid2">
        <div>
          <label htmlFor="t-repo">Repository</label>
          <input
            id="t-repo"
            value={data.repo ?? ''}
            placeholder="None"
            onChange={(e) => {
              const repo = e.target.value.trim() || undefined
              update(node.id, { repo, itemKind: data.pr && repo ? 'pr' : repo ? 'placeholder' : 'step' })
            }}
          />
        </div>
        <div>
          <label htmlFor="t-pr">Pull request</label>
          <input
            id="t-pr"
            inputMode="numeric"
            value={data.pr ?? ''}
            placeholder="Not opened"
            onChange={(e) => {
              const n = Number(e.target.value.replace(/^#/, ''))
              const pr = Number.isInteger(n) && n > 0 ? n : undefined
              update(node.id, { pr, itemKind: pr && data.repo ? 'pr' : data.repo ? 'placeholder' : 'step' })
            }}
          />
        </div>
        <div>
          <label htmlFor="t-status">Status</label>
          <select id="t-status" value={data.status} onChange={(e) => update(node.id, { status: e.target.value as Status })}>
            <option value="todo">To do</option>
            <option value="active">In progress</option>
            <option value="review">In review</option>
            <option value="blocked">Blocked</option>
            <option value="deferred">Deferred</option>
            <option value="done">Done</option>
          </select>
        </div>
        <div>
          <label htmlFor="t-who">Whose move</label>
          <select id="t-who" value={data.who ?? ''} onChange={(e) => update(node.id, { who: (e.target.value || undefined) as Who | undefined })}>
            <option value="">Not set</option>
            <option value="you">You</option>
            <option value="review">Reviewer</option>
            <option value="ci">CI</option>
          </select>
        </div>
      </div>
      {suggestions.length > 0 && (
        <div className="suggestions">
          <span className="label-text">Possible pull requests</span>
          {suggestions.map(({ pr, score }) => (
            <div className="suggestion" key={`${pr.repo}#${pr.number}`}>
              <div className="suggestion-copy">
                <a href={pr.url} target="_blank" rel="noreferrer">
                  {pr.title}
                </a>
                <span>
                  {pr.repo}#{pr.number} · {score >= 0.6 ? 'High' : score >= 0.35 ? 'Medium' : 'Low'} confidence
                </span>
              </div>
              <button type="button" className="btn" onClick={() => update(node.id, { repo: pr.repo, pr: pr.number, itemKind: 'pr' })}>
                Link
              </button>
            </div>
          ))}
        </div>
      )}
      <label htmlFor="t-note">Notes</label>
      <textarea id="t-note" rows={3} value={data.note ?? ''} onChange={(e) => update(node.id, { note: e.target.value || undefined })} />
      <p className="facts">
        Shown as <b>{STATUS_LABEL[st]}</b>
        {lev > 0 && <> · unblocks {lev}</>}
      </p>
      {connections && (
        <>
          <span className="label-text">Waits on</span>
          {list(work.preds.get(node.id) ?? [])}
          <span className="label-text">Unblocks</span>
          {list(work.succs.get(node.id) ?? [])}
        </>
      )}
    </div>
  )
}

export default function App() {
  return (
    <ReactFlowProvider>
      <Canvas />
    </ReactFlowProvider>
  )
}
