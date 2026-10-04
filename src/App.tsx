import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  Background,
  BackgroundVariant,
  Controls,
  MarkerType,
  MiniMap,
  Panel,
  ReactFlow,
  ReactFlowProvider,
  SelectionMode,
  applyNodeChanges,
  useReactFlow,
  useStore,
  type Connection,
  type Edge,
  type NodeChange,
  type NodeTypes,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import { ActionsContext, DerivedContext, deriveWork, traceFrom, type Derived, type GroupStats } from './derive'
import { sampleLinks, sampleNodes } from './fixture'
import { reflow, reflowAll } from './layout'
import {
  STATUS_LABEL,
  absPos,
  ancestors,
  byId,
  groupSelection,
  isCluster,
  isTask,
  normalize,
  sizeOf,
  ungroup,
  type AppNode,
  type ClusterData,
  type Link,
  type Status,
  type TaskData,
  type Who,
} from './model'
import { ClusterView, TaskView } from './nodes'

const nodeTypes: NodeTypes = { task: TaskView, cluster: ClusterView }
const STORAGE_KEY = 'orion:v1'
/**
 * Zoom below which a group reads as one body. Nested groups fold first as you
 * zoom out, so detail drops away from the inside.
 */
const COLLAPSE_ZOOM = 0.3
const COLLAPSE_STEP = 0.12

type Saved = { nodes: AppNode[]; links: Link[] }

function load(): Saved | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return null
    const s = JSON.parse(raw)
    if (!Array.isArray(s.nodes) || !Array.isArray(s.links)) return null
    return { nodes: normalize(s.nodes), links: s.links }
  } catch {
    return null
  }
}

function save({ nodes, links }: Saved) {
  try {
    const slim = nodes.map((n) => ({
      id: n.id,
      type: n.type,
      position: n.position,
      parentId: n.parentId,
      data: n.data,
      width: n.width,
      height: n.height,
    }))
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ nodes: slim, links }))
  } catch {
    // Saving is a convenience; the canvas keeps working without it.
  }
}

const ease = (t: number) => 1 - Math.pow(1 - t, 3)

function Canvas() {
  const rf = useReactFlow<AppNode, Edge>()
  const zoom = useStore((s) => s.transform[2])
  const [nodes, setNodes] = useState<AppNode[]>([])
  const [links, setLinks] = useState<Link[]>([])
  const [ready, setReady] = useState(false)
  const [root, setRoot] = useState<string | null>(null)
  const [hover, setHover] = useState<string | null>(null)
  const [editing, setEditing] = useState<string | null>(null)
  const [showHelp, setShowHelp] = useState(true)
  const latest = useRef({ nodes, links })
  useEffect(() => {
    latest.current = { nodes, links }
  }, [nodes, links])

  useEffect(() => {
    let cancelled = false
    const saved = load()
    const start = saved ? Promise.resolve(saved) : reflowAll(sampleNodes(), sampleLinks()).then((n) => ({ nodes: n, links: sampleLinks() }))
    start.then((s) => {
      if (cancelled) return
      setNodes(s.nodes)
      setLinks(s.links)
      setReady(true)
    })
    return () => {
      cancelled = true
    }
  }, [])

  useEffect(() => {
    if (!ready) return
    const t = setTimeout(() => save({ nodes, links }), 400)
    return () => clearTimeout(t)
  }, [nodes, links, ready])

  /**
   * Fits the opened group, or everything at the top level. Bounds come from our own
   * data because nodes hidden since load have never been measured by React Flow.
   */
  const fitTo = useCallback(
    (target: string | null) => {
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
      rf.fitBounds({ x: x0, y: y0, width: x1 - x0, height: y1 - y0 }, { padding: 0.12, duration: 450 })
    },
    [rf],
  )

  // The first fit comes from React Flow's fitView prop; this one follows opening and closing groups.
  const fittedFor = useRef<string | null>(null)
  useEffect(() => {
    if (fittedFor.current === root) return
    fittedFor.current = root
    fitTo(root)
  }, [root, fitTo])

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
  const work = useMemo(() => deriveWork(nodes, links), [nodes, links])

  // Which groups read as single bodies at this zoom, and which nodes that hides.
  const inView = useCallback((id: string) => !root || id === root || ancestors(id, map).includes(root), [root, map])
  const depthInView = (id: string) => {
    const chain = ancestors(id, map)
    return root ? chain.indexOf(root) : chain.length
  }
  const small = nodes
    .filter((n) => isCluster(n) && n.id !== root && inView(n.id) && zoom < COLLAPSE_ZOOM + COLLAPSE_STEP * depthInView(n.id))
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

  const viewNodes = useMemo(() => nodes.map((n) => (view.hidden.has(n.id) ? { ...n, hidden: true } : n)), [nodes, view])

  const trace = useMemo(() => {
    const h = hover ? map.get(hover) : undefined
    return h && isTask(h)
      ? traceFrom(
          h.id,
          work.preds,
          work.succs,
          nodes.filter(isTask).map((n) => n.id),
        )
      : null
  }, [hover, map, work, nodes])

  const edges = useMemo(() => {
    const out: Edge[] = []
    const marker = (live: boolean) => ({ type: MarkerType.ArrowClosed, width: 14, height: 14, color: live ? 'var(--edge-hot)' : 'var(--edge)' })
    const agg = new Map<string, { a: string; b: string; count: number; live: boolean }>()
    for (const l of links) {
      const a = view.rep(l.from)
      const b = view.rep(l.to)
      if (!a || !b || a === b) continue
      const live = l.kind === 'blocks' && work.status.get(l.from) !== 'done'
      if (a === l.from && b === l.to) {
        let cls = l.kind === 'related' ? 'e-rel' : live ? 'e-live' : 'e-done'
        if (trace) {
          const ra = trace.get(l.from)
          const rb = trace.get(l.to)
          const up = l.kind === 'blocks' && ra === 'up' && (rb === 'up' || rb === 'self')
          const down = l.kind === 'blocks' && (ra === 'down' || ra === 'self') && rb === 'down'
          cls += up ? ' tr-e-up' : down ? ' tr-e-down' : ' tr-e-dim'
        }
        out.push({
          id: l.id,
          source: l.from,
          target: l.to,
          className: cls,
          selectable: false,
          markerEnd: l.kind === 'blocks' ? marker(live) : undefined,
        })
      } else if (l.kind === 'blocks') {
        const k = a + '>' + b
        const e = agg.get(k) ?? { a, b, count: 0, live: false }
        e.count++
        e.live ||= live
        agg.set(k, e)
      }
    }
    for (const [k, e] of agg) {
      out.push({
        id: 'agg:' + k,
        source: e.a,
        target: e.b,
        className: 'e-agg ' + (e.live ? 'e-live' : 'e-done'),
        selectable: false,
        label: e.count > 1 ? `${e.count} links` : undefined,
        markerEnd: marker(e.live),
        style: { strokeWidth: Math.min(6, 1.5 + e.count * 0.8) },
      })
    }
    return out
  }, [links, view, work, trace])

  const derived = useMemo<Derived>(
    () => ({ status: work.status, leverage: work.leverage, groups: work.groups, trace, collapsed, zoom }),
    [work, trace, collapsed, zoom],
  )

  const onNodesChange = useCallback((changes: NodeChange<AppNode>[]) => setNodes((ns) => applyNodeChanges(changes, ns)), [])
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

  const select = useCallback(
    (id: string) => setNodes((ns) => ns.map((n) => (n.id === id ? { ...n, selected: true } : n.selected ? { ...n, selected: false } : n))),
    [],
  )

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
      if (root && targets.includes(root)) setRoot(map.get(root)?.parentId ?? null)
      setNodes(ungroup(nodes, targets))
    },
    [nodes, selected, root, map],
  )

  const actions = useMemo(
    () => ({
      reflow: (gid: string) => {
        const { nodes: ns, links: ls } = latest.current
        reflow(ns, ls, gid).then(tweenTo)
      },
      open: (gid: string) => {
        setRoot(gid)
        setHover(null)
      },
    }),
    [tweenTo],
  )

  const tidy = () => reflow(nodes, links, root ?? undefined).then(tweenTo)
  const reset = () => {
    const l = sampleLinks()
    setRoot(null)
    reflowAll(sampleNodes(), l).then((n) => {
      setNodes(n)
      setLinks(l)
      setTimeout(() => fitTo(null), 40)
    })
  }

  const goTo = (id: string) => {
    const n = map.get(id)
    if (!n) return
    if (!inView(id)) setRoot(null)
    select(id)
    const p = absPos(n, map)
    const s = sizeOf(n)
    rf.setCenter(p.x + s.w / 2, p.y + s.h / 2, { zoom: Math.max(zoom, 1), duration: 450 })
  }

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement).closest('input, textarea, select')) return
      if (e.metaKey && e.key.toLowerCase() === 'g') {
        e.preventDefault()
        if (e.shiftKey) doUngroup()
        else doGroup()
      } else if (e.key === 'Enter' && selected.length === 1 && isCluster(selected[0])) {
        actions.open(selected[0].id)
      } else if (e.key === 'Escape') {
        if (root) setRoot(map.get(root)?.parentId ?? null)
        else setNodes((ns) => ns.map((n) => (n.selected ? { ...n, selected: false } : n)))
      } else if (e.shiftKey && e.code === 'Digit1') {
        fitTo(root)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [doGroup, doUngroup, selected, actions, root, map, fitTo])

  const updateData = (id: string, patch: Partial<TaskData> | Partial<ClusterData>) =>
    setNodes((ns) => ns.map((n) => (n.id === id ? ({ ...n, data: { ...n.data, ...patch } } as AppNode) : n)))

  const crumbs = root ? [...ancestors(root, map).reverse(), root] : []
  const one = selected.length === 1 ? selected[0] : null

  return (
    <DerivedContext.Provider value={derived}>
      <ActionsContext.Provider value={actions}>
        {ready && (
          <ReactFlow<AppNode, Edge>
            fitView
            fitViewOptions={{ padding: 0.12 }}
            nodes={viewNodes}
            edges={edges}
            nodeTypes={nodeTypes}
            onNodesChange={onNodesChange}
            onNodeDragStop={onDragStop}
            onConnect={onConnect}
            onNodeMouseEnter={(_, n) => isTask(n) && setHover(n.id)}
            onNodeMouseLeave={() => setHover(null)}
            onNodeDoubleClick={(_, n) => isCluster(n) && actions.open(n.id)}
            selectionOnDrag
            panOnDrag={[1, 2]}
            panOnScroll
            selectionMode={SelectionMode.Full}
            multiSelectionKeyCode={['Meta', 'Shift']}
            deleteKeyCode={null}
            zoomOnDoubleClick={false}
            minZoom={0.06}
            maxZoom={2}
            colorMode="system"
          >
            <Background variant={BackgroundVariant.Dots} gap={24} size={1.3} color="var(--dots)" />
            <Controls showInteractive={false} />
            <MiniMap pannable zoomable nodeClassName={(n) => (n.type === 'cluster' ? 'mm-cluster' : 'mm-' + (work.status.get(n.id) ?? 'ready'))} />

            <Panel position="top-left" className="panel crumbs">
              <button type="button" className={root ? 'crumb' : 'crumb current'} onClick={() => setRoot(null)}>
                All work
              </button>
              {crumbs.map((id) => (
                <span key={id} className="crumb-wrap">
                  <span className="sep">›</span>
                  <button type="button" className={id === root ? 'crumb current' : 'crumb'} onClick={() => setRoot(id)}>
                    {(map.get(id)?.data as ClusterData | undefined)?.label}
                  </button>
                </span>
              ))}
              <span className="crumb-actions">
                <button type="button" className="btn" onClick={tidy}>
                  Tidy {root ? 'group' : 'canvas'}
                </button>
                <button type="button" className="btn" onClick={reset}>
                  Reset sample
                </button>
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
                ) : isTask(one) ? (
                  <TaskInspector key={one.id} node={one} work={work} map={map} update={updateData} goTo={goTo} />
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

            <Panel position="bottom-center" className="panel help">
              {showHelp ? (
                <>
                  Drag to select · ⌘ or ⇧ click to add · ⌘G group · ⇧⌘G ungroup · double-click a group to open · Esc to go up · scroll or space-drag
                  to pan · pinch to zoom · ⇧1 fit · drag from a card's edge to link{' '}
                  <button type="button" className="link" onClick={() => setShowHelp(false)}>
                    Hide
                  </button>
                </>
              ) : (
                <button type="button" className="link" onClick={() => setShowHelp(true)}>
                  Shortcuts
                </button>
              )}
            </Panel>
          </ReactFlow>
        )}
        {!ready && <div className="loading">Laying out…</div>}
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

function TaskInspector({
  node,
  work,
  map,
  update,
  goTo,
}: {
  node: AppNode
  work: ReturnType<typeof deriveWork>
  map: Map<string, AppNode>
  update: (id: string, patch: Partial<TaskData>) => void
  goTo: (id: string) => void
}) {
  const data = node.data as TaskData
  const st = work.status.get(node.id) ?? 'ready'
  const lev = work.leverage.get(node.id) ?? 0
  const list = (ids: string[]) =>
    ids.length ? (
      <ul>
        {ids.map((id) => (
          <li key={id}>
            <button type="button" className="link" onClick={() => goTo(id)}>
              {(map.get(id)?.data as TaskData | undefined)?.label} <span>({STATUS_LABEL[work.status.get(id) ?? 'ready']})</span>
            </button>
          </li>
        ))}
      </ul>
    ) : (
      <p className="facts">Nothing</p>
    )
  return (
    <div className="insp">
      <label htmlFor="t-label">Title</label>
      <input id="t-label" value={data.label} onChange={(e) => update(node.id, { label: e.target.value })} />
      <div className="grid2">
        <div>
          <label htmlFor="t-tag">Reference</label>
          <input id="t-tag" value={data.tag} onChange={(e) => update(node.id, { tag: e.target.value })} />
        </div>
        <div>
          <label htmlFor="t-status">Status</label>
          <select id="t-status" value={data.status} onChange={(e) => update(node.id, { status: e.target.value as Status })}>
            <option value="todo">To do</option>
            <option value="active">In progress</option>
            <option value="review">In review</option>
            <option value="done">Done</option>
          </select>
        </div>
      </div>
      <label htmlFor="t-who">Whose move</label>
      <select id="t-who" value={data.who ?? ''} onChange={(e) => update(node.id, { who: (e.target.value || undefined) as Who | undefined })}>
        <option value="">Not set</option>
        <option value="you">You</option>
        <option value="review">Reviewer</option>
        <option value="ci">CI</option>
      </select>
      <p className="facts">
        Shown as <b>{STATUS_LABEL[st]}</b>
        {lev > 0 && <> · unblocks {lev}</>}
      </p>
      <span className="label-text">Waits on</span>
      {list(work.preds.get(node.id) ?? [])}
      <span className="label-text">Unblocks</span>
      {list(work.succs.get(node.id) ?? [])}
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
