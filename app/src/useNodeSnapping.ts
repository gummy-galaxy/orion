import { useCallback, useMemo, useRef, useState, type Dispatch, type SetStateAction } from 'react'
import { useReactFlow, type NodeChange } from '@xyflow/react'
import { liftNodes, unliftNodes } from './lift'
import { byId, isCluster, normalize, type AppNode } from './model'
import { pushAside } from './pushAside'
import { finishDrag, snapDrag, snapGuides } from './snap'
import type { CardSize } from './cardSize'

const SNAP_PX = 8
/**
 * Siblings farther than this (on screen, edge to edge) cannot pull a dragged node. It is wider than
 * the widest gap the top-level layout leaves (120 canvas units), so a neighbor one gap away still snaps,
 * and narrower than three stacked cards in a group (216 canvas units), so a card does not snap to the far end.
 */
const SNAP_REACH_PX = 160
const THROW_SPEED = 0.8
const THROW_WINDOW_MS = 90

/** `before` is the canvas as the drag found it, so a group the drop grows can push its neighbors aside. */
type DragSession = { ids: Set<string>; free: boolean; samples: { x: number; y: number; time: number }[]; before: AppNode[] }
type DragEvent = MouseEvent | TouchEvent

/** Owns snapping's drag state while the canvas keeps its other node-change behavior. */
export function useNodeSnapping({
  nodes,
  getCurrentNodes,
  setNodes,
  tweenTo,
  cardSize,
}: {
  nodes: AppNode[]
  getCurrentNodes: () => AppNode[]
  setNodes: Dispatch<SetStateAction<AppNode[]>>
  tweenTo: (nodes: AppNode[]) => void
  cardSize: CardSize
}) {
  const reactFlow = useReactFlow()
  const dragOrigins = useRef(new Map<string, AppNode['position']>())
  const drag = useRef<DragSession | null>(null)
  const [skipSnapGuides, setSkipSnapGuides] = useState(false)

  const snapChanges = useCallback(
    (changes: NodeChange<AppNode>[]) => {
      // Capture the session before queueing the node update; the last position change can arrive just before drag stop.
      const session = drag.current
      const movedIds =
        session && !session.free ? changes.flatMap((change) => (change.type === 'position' && session.ids.has(change.id) ? [change.id] : [])) : []
      const tolerance = SNAP_PX / reactFlow.getZoom()
      const reach = SNAP_REACH_PX / reactFlow.getZoom()

      return (changedNodes: AppNode[]) => (movedIds.length ? snapDrag(changedNodes, movedIds, tolerance, reach, cardSize) : changedNodes)
    },
    [reactFlow, cardSize],
  )

  const onDragStart = useCallback(
    (event: DragEvent, dragged: { id: string }[]) => {
      const ids = new Set(dragged.map((node) => node.id))

      const before = getCurrentNodes()

      drag.current = { ids, free: event.ctrlKey, samples: [], before }
      setSkipSnapGuides(event.ctrlKey)
      setNodes((currentNodes) => liftNodes(currentNodes, ids))
      const nodeMap = byId(before)

      dragOrigins.current = new Map()

      for (const draggedNode of dragged) {
        const node = nodeMap.get(draggedNode.id)
        const parent = node?.parentId ? nodeMap.get(node.parentId) : undefined

        if (node && parent && isCluster(parent) && parent.data.arrange !== 'custom') dragOrigins.current.set(node.id, node.position)
      }
    },
    [getCurrentNodes, setNodes],
  )

  const onDrag = useCallback((event: DragEvent) => {
    const session = drag.current

    if (!session) return

    session.free = event.ctrlKey
    setSkipSnapGuides(event.ctrlKey)
    const point = 'touches' in event ? event.touches[0] : event

    if (point) session.samples = [...session.samples.slice(-7), { x: point.clientX, y: point.clientY, time: performance.now() }]
  }, [])

  const onDragStop = useCallback(
    (event: DragEvent) => {
      const session = drag.current

      drag.current = null
      setSkipSnapGuides(false)
      const origins = dragOrigins.current

      dragOrigins.current = new Map()

      if (!session) return setNodes((currentNodes) => normalize(currentNodes, cardSize))

      const released = (currentNodes: AppNode[]) => pushAside(session.before, normalize(unliftNodes(currentNodes, session.ids), cardSize), cardSize)
      const now = performance.now()
      const recentSamples = session.samples.filter((sample) => now - sample.time <= THROW_WINDOW_MS)
      const firstSample = recentSamples[0]
      const lastSample = recentSamples[recentSamples.length - 1]
      const thrown =
        !!firstSample &&
        lastSample.time > firstSample.time &&
        Math.hypot(lastSample.x - firstSample.x, lastSample.y - firstSample.y) / (lastSample.time - firstSample.time) >= THROW_SPEED
      const draggedIds = [...session.ids]

      if (!origins.size && (session.free || event.ctrlKey || !draggedIds.length)) return setNodes(released)

      requestAnimationFrame(() => {
        const currentNodes = getCurrentNodes()
        const finished = finishDrag(currentNodes, origins, draggedIds, session.free || event.ctrlKey, thrown, cardSize)
        const result = released(finished)

        if (finished !== currentNodes) tweenTo(result)
        else setNodes(result)
      })
    },
    [getCurrentNodes, setNodes, tweenTo, cardSize],
  )

  // Zoom is read here, not subscribed to, so guides refresh its reach on the next node change.
  const guides = useMemo(
    () => (skipSnapGuides ? [] : snapGuides(nodes, SNAP_REACH_PX / reactFlow.getZoom(), cardSize)),
    [nodes, skipSnapGuides, cardSize, reactFlow],
  )

  return { snapChanges, onDragStart, onDrag, onDragStop, guides }
}
