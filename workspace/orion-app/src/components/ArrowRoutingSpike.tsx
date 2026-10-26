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
import { routeBundles } from '../routing/routeBundles'
import { routeCurves } from '../routing/routeCurves'
import { sceneOf } from '../routing/sceneOf'
import type { Routing, Scene } from '../routing/types'
import { linksAtom, nodesAtom } from '../state'
import { ClusterView } from './ClusterView'
import { RoutedEdge, type RoutedEdgeData } from './RoutedEdge'
import { RoutingPanel, type RoutingStats } from './RoutingPanel'
import { TaskView } from './TaskView'

const nodeTypes: NodeTypes = { task: TaskView, cluster: ClusterView }
const edgeTypes: EdgeTypes = { routed: RoutedEdge }
const noResize = { start: () => {}, move: () => {}, end: () => {}, active: () => false }
const actions = { open: () => {}, reflow: () => {}, celebrate: () => {}, resizeGroup: noResize }
const MARKER = { type: MarkerType.ArrowClosed, width: 14, height: 14, color: 'var(--edge-still)' }
const LABEL = { labelBgPadding: [5, 2] as [number, number], labelBgBorderRadius: 4, labelStyle: { fontSize: 11, fontWeight: 600 } }
/** Frames kept for the running average. */
const WINDOW = 60

type Router = (scene: Scene) => Routing

/**
 * The arrow routing spike for #26: the same messy canvas drawn by each approach, with cards you can drag so every
 * frame reroutes, and a readout of how long routing took.
 */
export function ArrowRoutingSpike({ approach: initialApproach, size: initialSize }: { approach: Approach; size: Size }) {
  const [approach, setApproach] = useState(initialApproach)
  const [size, setSize] = useState(initialSize)
  const canvas = useMemo(() => buildMessyCanvas({ links: size }), [size])
  const [nodes, setNodes] = useState<AppNode[]>(canvas.nodes)
  const [store] = useState(() => createStore())
  const [avoidRouter, setAvoidRouter] = useState<Router | null>(null)
  const timings = useRef<number[]>([])
  const drawn = useRef(new Map<string, Edge<RoutedEdgeData>>())

  useEffect(() => setApproach(initialApproach), [initialApproach])
  useEffect(() => setSize(initialSize), [initialSize])

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

    if (size > AVOID_LIMIT) return null

    return avoidRouter
  }, [approach, size, avoidRouter, canvas])

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
      note,
    }
  }, [routing, elapsed, router, approach, size])

  // Lines whose path didn't change keep their edge object, so React Flow skips redrawing them.
  const edges = useMemo(() => {
    const next = new Map<string, Edge<RoutedEdgeData>>()

    for (const line of routing.lines) {
      const known = drawn.current.get(line.id)

      if (known && known.data!.d === line.d) {
        next.set(line.id, known)
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

  const onNodesChange = (changes: NodeChange<AppNode>[]) => setNodes((current) => applyNodeChanges(changes, current))

  return (
    <Provider store={store}>
      <ActionsContext.Provider value={actions}>
        <ReactFlowProvider>
          <div className="canvas" style={{ position: 'fixed', inset: 0 }}>
            <RoutingPanel
              approach={approach}
              size={size}
              stats={stats}
              onApproach={setApproach}
              onSize={(next) => {
                if (approach === 'libavoid' && next > AVOID_LIMIT) return

                setSize(next)
              }}
            />
            <ReactFlow
              nodes={nodes}
              edges={edges}
              nodeTypes={nodeTypes}
              edgeTypes={edgeTypes}
              onNodesChange={onNodesChange}
              minZoom={0.05}
              fitView
              fitViewOptions={{ padding: 0.06 }}
              proOptions={{ hideAttribution: true }}
            />
          </div>
        </ReactFlowProvider>
      </ActionsContext.Provider>
    </Provider>
  )
}
