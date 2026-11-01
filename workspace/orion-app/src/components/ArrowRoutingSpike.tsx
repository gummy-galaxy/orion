import { useEffect, useMemo, useRef, useState } from 'react'
import { Provider, createStore } from 'jotai'
import { MarkerType, ReactFlow, ReactFlowProvider, applyNodeChanges, type Edge, type EdgeTypes, type NodeChange, type NodeTypes } from '@xyflow/react'
// The package's exports hide its .wasm file, so the URL comes from its path on disk.
import wasmUrl from '../../node_modules/libavoid-js/dist/libavoid.wasm?url'
import { ActionsContext } from '../derive'
import type { AppNode } from '../model'
import { AVOID_LIMIT, type Approach, type Size } from '../routing/approaches'
import { buildMessyCanvas } from '../routing/buildMessyCanvas'
import { createAvoidRouter, loadAvoid } from '../routing/createAvoidRouter'
import { createLaneRouter } from '../routing/createLaneRouter'
import { curvePath } from '../routing/curvePath'
import { sourcePort, targetPort } from '../routing/ports'
import { routeBundles } from '../routing/routeBundles'
import { routeCurves } from '../routing/routeCurves'
import { routePlugs } from '../routing/routePlugs'
import { sceneOf } from '../routing/sceneOf'
import type { Plug, RoutedLine, Routing, Scene } from '../routing/types'
import { linksAtom, nodesAtom } from '../state'
import { ClusterView } from './ClusterView'
import { PlugContext, type PlugActions } from './PlugContext'
import { PlugEdge, type PlugEdgeData } from './PlugEdge'
import { RoutedEdge, type RoutedEdgeData } from './RoutedEdge'
import { RoutingPanel, type RoutingStats } from './RoutingPanel'
import { TaskView } from './TaskView'

const nodeTypes: NodeTypes = { task: TaskView, cluster: ClusterView }
const edgeTypes: EdgeTypes = { routed: RoutedEdge, plug: PlugEdge }
const noResize = { start: () => {}, move: () => {}, end: () => {}, active: () => false }
const actions = { open: () => {}, reflow: () => {}, celebrate: () => {}, resizeGroup: noResize }
const MARKER = { type: MarkerType.ArrowClosed, width: 14, height: 14, color: 'var(--edge-still)' }
const LABEL = { labelBgPadding: [5, 2] as [number, number], labelBgBorderRadius: 4, labelStyle: { fontSize: 11, fontWeight: 600 } }
/** Fits the canvas below the panel, so the panel never covers the top-left group. */
const FIT = { padding: { top: '230px', right: '24px', bottom: '24px', left: '24px' } }
/** Frames kept for the running average. */
const WINDOW = 60
/** How long a card stays marked after a plug jumps to it. */
const FLASH_MS = 1600
// The ring a plug puts around the card at its far end, and the links it draws in full while hovered.
const PLUG_STYLES = `
.react-flow__node.plug-target { outline: 3px solid var(--accent-default); outline-offset: 4px; border-radius: 14px; }
.react-flow__edge.e-reveal .react-flow__edge-path { stroke: var(--accent-default); stroke-width: 2.5; stroke-dasharray: 6 4; }
.react-flow__edgelabel-renderer { z-index: 1000; }
`

type SpikeEdgeData = RoutedEdgeData | PlugEdgeData

type Router = (scene: Scene) => Routing

/**
 * The arrow routing spike for #26: the same messy canvas drawn by each approach, with cards you can drag so every
 * frame reroutes, and a readout of how long routing took.
 */
export function ArrowRoutingSpike({
  approach: initialApproach,
  size: initialSize,
  threshold: initialThreshold,
}: {
  approach: Approach
  size: Size
  threshold: number
}) {
  const [approach, setApproach] = useState(initialApproach)
  const [size, setSize] = useState(initialSize)
  const [threshold, setThreshold] = useState(initialThreshold)
  const [revealed, setRevealed] = useState<Plug | null>(null)
  const [flashed, setFlashed] = useState<string | null>(null)
  const canvas = useMemo(() => buildMessyCanvas({ links: size }), [size])
  const [nodes, setNodes] = useState<AppNode[]>(canvas.nodes)
  const [store] = useState(() => createStore())
  const [avoidRouter, setAvoidRouter] = useState<Router | null>(null)
  const timings = useRef<number[]>([])
  const drawn = useRef(new Map<string, Edge<SpikeEdgeData>>())

  useEffect(() => setApproach(initialApproach), [initialApproach])
  useEffect(() => setSize(initialSize), [initialSize])
  useEffect(() => setThreshold(initialThreshold), [initialThreshold])

  useEffect(() => {
    if (!flashed) return

    const timer = setTimeout(() => setFlashed(null), FLASH_MS)

    return () => clearTimeout(timer)
  }, [flashed])

  const plugActions: PlugActions = useMemo(() => ({ reveal: setRevealed, flash: setFlashed }), [])

  useEffect(() => {
    setNodes(canvas.nodes)
    store.set(nodesAtom, canvas.nodes)
    store.set(linksAtom, canvas.links)
  }, [canvas, store])

  useEffect(() => {
    if (approach !== 'libavoid') return

    let router: ReturnType<typeof createAvoidRouter> | null = null
    let cancelled = false

    void loadAvoid(wasmUrl).then((Avoid) => {
      if (cancelled) return

      router = createAvoidRouter(Avoid)
      setAvoidRouter(() => router!.route)
    })

    return () => {
      cancelled = true
      router?.dispose()
      setAvoidRouter(null)
    }
  }, [approach])

  // Each approach and size starts its own router, so a cached route from one never leaks into another.
  const router = useMemo<Router | null>(() => {
    timings.current = []

    if (approach === 'curves') return routeCurves

    if (approach === 'bundles') return routeBundles

    if (approach === 'lanes') return createLaneRouter().route

    if (approach === 'plugs' || approach === 'plugBundles') {
      return (scene: Scene) => routePlugs(scene, { threshold, bundles: approach === 'plugBundles' })
    }

    if (size > AVOID_LIMIT) return null

    return avoidRouter
  }, [approach, size, avoidRouter, canvas, threshold])

  const scene = useMemo(() => sceneOf(nodes, canvas.links), [nodes, canvas])

  const { routing, elapsed } = useMemo(() => {
    if (!router) return { routing: { lines: [], fallbacks: 0 }, elapsed: 0 }

    const start = performance.now()
    const routing = router(scene)

    return { routing, elapsed: performance.now() - start }
  }, [router, scene])

  const stats: RoutingStats = useMemo(() => {
    if (router) {
      timings.current.push(elapsed)

      if (timings.current.length > WINDOW) timings.current.shift()
    }

    const frames = timings.current.length
    const note =
      approach === 'libavoid' && size > AVOID_LIMIT
        ? `libavoid takes seconds past ${AVOID_LIMIT} links, so it only runs on the smallest canvas here.`
        : approach === 'libavoid' && !router
          ? 'Loading libavoid…'
          : undefined

    return {
      lastMs: elapsed,
      averageMs: frames ? timings.current.reduce((sum, value) => sum + value, 0) / frames : 0,
      maxMs: frames ? Math.max(...timings.current) : 0,
      frames,
      fallbacks: routing.fallbacks,
      lines: routing.lines.length,
      stubbed: routing.stubbed,
      note,
    }
  }, [routing, elapsed, router, approach, size])

  // Lines whose path didn't change keep their edge object, so React Flow skips redrawing them.
  const edges = useMemo(() => {
    const next = new Map<string, Edge<SpikeEdgeData>>()

    for (const line of routing.lines) {
      const known = drawn.current.get(line.id)

      if (known && known.data!.d === line.d && samePlug(known.data, line)) {
        next.set(line.id, known)
        continue
      }

      if (line.plug) {
        next.set(line.id, {
          id: line.id,
          type: 'plug',
          source: line.source,
          target: line.target,
          className: 'e-still',
          selectable: false,
          data: { d: line.d, plug: line.plug },
          markerEnd: line.arrow ? MARKER : undefined,
        })
        continue
      }

      next.set(line.id, {
        id: line.id,
        type: 'routed',
        source: line.source,
        target: line.target,
        className: 'e-still',
        selectable: false,
        data: { d: line.d, labelAt: line.labelAt },
        markerEnd: line.arrow ? MARKER : undefined,
        style: line.width ? { strokeWidth: line.width } : undefined,
        ...(line.label ? { label: line.label, ...LABEL } : {}),
      })
    }

    drawn.current = next

    return [...next.values()]
  }, [routing])

  // A hovered plug draws its links in full on top, and rings the cards at their far ends.
  const revealedLinks = useMemo(() => {
    if (!revealed) return []

    const cards = new Map(scene.cards.map((card) => [card.id, card]))

    return scene.links
      .filter((link) => revealed.links.includes(link.id))
      .map((link): Edge<RoutedEdgeData> => ({
        id: `reveal:${link.id}`,
        type: 'routed',
        source: link.from,
        target: link.to,
        className: 'e-reveal',
        selectable: false,
        zIndex: 1000,
        data: { d: curvePath(sourcePort(cards.get(link.from)!), targetPort(cards.get(link.to)!)) },
        markerEnd: MARKER,
      }))
  }, [revealed, scene])

  const ringed = useMemo(() => {
    const ids = new Set(revealedLinks.map((edge) => (revealed!.side === 'out' ? edge.target : edge.source)))

    if (flashed) ids.add(flashed)

    return ids
  }, [revealedLinks, revealed, flashed])

  const shownNodes = useMemo(
    () => (ringed.size ? nodes.map((node) => (ringed.has(node.id) ? { ...node, className: 'plug-target' } : node)) : nodes),
    [nodes, ringed],
  )
  const shownEdges = useMemo(() => (revealedLinks.length ? [...edges, ...revealedLinks] : edges), [edges, revealedLinks])

  const onNodesChange = (changes: NodeChange<AppNode>[]) => setNodes((current) => applyNodeChanges(changes, current))

  return (
    <Provider store={store}>
      <ActionsContext.Provider value={actions}>
        <ReactFlowProvider>
          <PlugContext.Provider value={plugActions}>
            <style>{PLUG_STYLES}</style>
            <div className="canvas" style={{ position: 'fixed', inset: 0 }}>
              <RoutingPanel
                approach={approach}
                size={size}
                threshold={threshold}
                stats={stats}
                onApproach={setApproach}
                onThreshold={setThreshold}
                onSize={(next) => {
                  if (approach === 'libavoid' && next > AVOID_LIMIT) return

                  setSize(next)
                }}
              />
              <ReactFlow
                nodes={shownNodes}
                edges={shownEdges}
                nodeTypes={nodeTypes}
                edgeTypes={edgeTypes}
                onNodesChange={onNodesChange}
                minZoom={0.05}
                fitView
                fitViewOptions={FIT}
                proOptions={{ hideAttribution: true }}
              />
            </div>
          </PlugContext.Provider>
        </ReactFlowProvider>
      </ActionsContext.Provider>
    </Provider>
  )
}

/** Whether a cached plug edge still stands for the same far card and links. */
function samePlug(data: SpikeEdgeData | undefined, line: RoutedLine) {
  const plug = data && 'plug' in data ? data.plug : undefined

  if (!plug || !line.plug) return !plug && !line.plug

  return plug.card === line.plug.card && plug.links.join() === line.plug.links.join() && plug.at.x === line.plug.at.x && plug.at.y === line.plug.at.y
}
