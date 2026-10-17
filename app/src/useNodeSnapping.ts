import { useCallback, useMemo, useRef, useState, type Dispatch, type SetStateAction } from 'react'
import { useReactFlow, type NodeChange } from '@xyflow/react'
import { useSetAtom } from 'jotai'
import { POP_DISTANCE, dropTarget, followEscape, reparent, startEscape, type Escape } from './escape'
import { liftNodes, unliftNodes } from './lift'
import { byId, isCluster, normalize, pruneEmptied, type AppNode } from './model'
import { pushAside } from './pushAside'
import { finishDrag, snapDrag, snapGuides } from './snap'
import { dropTargetAtom } from './state'
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

/**
 * `before` is the canvas as the drag found it, so a group the drop grows can push its neighbors aside. `escape` tracks
 * the group the dragged work is leaving, if any.
 */
type DragSession = {
  ids: Set<string>
  free: boolean
  samples: { x: number; y: number; time: number }[]
  before: AppNode[]
  escape: Escape | null
}
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
  const setDropTarget = useSetAtom(dropTargetAtom)

  const snapChanges = useCallback(
    (changes: NodeChange<AppNode>[]) => {
      // Capture the session before queueing the node update; the last position change can arrive just before drag stop.
      const session = drag.current
      const movedIds =
        session && !session.free ? changes.flatMap((change) => (change.type === 'position' && session.ids.has(change.id) ? [change.id] : [])) : []
      const tolerance = SNAP_PX / reactFlow.getZoom()
      const reach = SNAP_REACH_PX / reactFlow.getZoom()
      const pop = POP_DISTANCE / reactFlow.getZoom()
      // Read once here, so the updater gives the same answer however many times React calls it.
      const escape = session?.escape

      return (changedNodes: AppNode[]) => {
        if (!movedIds.length) return changedNodes

        const snapped = snapDrag(changedNodes, movedIds, tolerance, reach, cardSize)

        if (!session || !escape) return snapped

        const followed = followEscape(snapped, escape, session.before, pop, cardSize)

        session.escape = followed.escape

        return followed.nodes
      }
    },
    [reactFlow, cardSize],
  )

  const onDragStart = useCallback(
    (event: DragEvent, dragged: { id: string }[]) => {
      const ids = new Set(dragged.map((node) => node.id))
      const before = getCurrentNodes()

      drag.current = { ids, free: event.ctrlKey, samples: [], before, escape: startEscape(before, ids, cardSize) }
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
    [getCurrentNodes, setNodes, cardSize],
  )

  const onDrag = useCallback(
    (event: DragEvent) => {
      const session = drag.current

      if (!session) return

      session.free = event.ctrlKey
      setSkipSnapGuides(event.ctrlKey)
      const point = 'touches' in event ? event.touches[0] : event

      if (point) session.samples = [...session.samples.slice(-7), { x: point.clientX, y: point.clientY, time: performance.now() }]

      const escape = session.escape
      const target = escape ? dropTarget(getCurrentNodes(), escape, cardSize) : undefined

      // Only a group that isn't the one the work started in is highlighted. Landing at the top level has nothing to show.
      setDropTarget(escape && target && target !== escape.from ? target : null)
    },
    [getCurrentNodes, cardSize, setDropTarget],
  )

  const onDragStop = useCallback(
    (event: DragEvent) => {
      const session = drag.current

      drag.current = null
      setSkipSnapGuides(false)
      setDropTarget(null)
      const origins = dragOrigins.current

      dragOrigins.current = new Map()

      if (!session) return setNodes((currentNodes) => normalize(currentNodes, cardSize))

      // The drop is the edit, so a group the drag took its last card out of goes, judged against where the drag began.
      const released = (currentNodes: AppNode[]) =>
        pushAside(session.before, pruneEmptied(session.before, normalize(unliftNodes(currentNodes, session.ids), cardSize)), cardSize)
      const now = performance.now()
      const recentSamples = session.samples.filter((sample) => now - sample.time <= THROW_WINDOW_MS)
      const firstSample = recentSamples[0]
      const lastSample = recentSamples[recentSamples.length - 1]
      const thrown =
        !!firstSample &&
        lastSample.time > firstSample.time &&
        Math.hypot(lastSample.x - firstSample.x, lastSample.y - firstSample.y) / (lastSample.time - firstSample.time) >= THROW_SPEED
      const draggedIds = [...session.ids]

      // The last position change lands a frame after drag stop, so where the work ended up is read then.
      requestAnimationFrame(() => {
        const currentNodes = getCurrentNodes()
        const escape = session.escape
        const target = escape ? dropTarget(currentNodes, escape, cardSize) : undefined

        // Work dropped into another group, or popped out of its own, lands where it was let go.
        if (escape && target !== escape.from)
          return setNodes((latestNodes) =>
            pushAside(
              session.before,
              pruneEmptied(session.before, normalize(reparent(unliftNodes(latestNodes, session.ids), escape.roots, target, escape.from), cardSize)),
              cardSize,
            ),
          )

        if (!origins.size && (session.free || event.ctrlKey || !draggedIds.length)) return setNodes(released)

        const finished = finishDrag(currentNodes, origins, draggedIds, session.free || event.ctrlKey, thrown, cardSize)
        const result = released(finished)

        if (finished !== currentNodes) tweenTo(result)
        else setNodes(result)
      })
    },
    [getCurrentNodes, setNodes, tweenTo, cardSize, setDropTarget],
  )

  // Zoom is read here, not subscribed to, so guides refresh its reach on the next node change.
  const guides = useMemo(
    () => (skipSnapGuides ? [] : snapGuides(nodes, SNAP_REACH_PX / reactFlow.getZoom(), cardSize)),
    [nodes, skipSnapGuides, cardSize, reactFlow],
  )

  return { snapChanges, onDragStart, onDrag, onDragStop, guides }
}
