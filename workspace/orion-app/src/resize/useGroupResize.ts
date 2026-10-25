import { GROUP_PADDING } from '../geometry'
import { useCallback, useMemo, useRef, type Dispatch, type SetStateAction } from 'react'
import { useReactFlow } from '@xyflow/react'
import { useSetAtom } from 'jotai'
import { planReflow, type ReflowPlan } from '../layout'
import { groupHeaderHeight, isCluster, sizeOf, type AppNode, type Link } from '../model'
import { pushAside } from '../pushAside'
import { resizeHandlesAtom } from '../state'
import type { CardSize } from '../cardSize'
import { resizeAutoGroup } from './resizeAutoGroup'
import { resizeBox } from './resizeBox'
import { resizeCustomGroup } from './resizeCustomGroup'
import type { Box, GroupResize, Point, ResizeEdges } from './types'

/**
 * One resize. `before` is the canvas when it began, so every frame starts from the same place and neighbors pushed
 * aside move back if the group shrinks again. An automatic group's layout is planned once, and `plan` stays undefined
 * until that's done.
 */
type Session = {
  id: string
  edges: ResizeEdges
  origin: Point
  point: Point
  zoom: number
  before: AppNode[]
  start: Box
  custom: boolean
  plan: ReflowPlan | null | undefined
  frame: number | null
  ended: boolean
}

/**
 * Resizes groups from their edges and corners. The canvas follows each frame on its own, and the result saves when the
 * resize ends, like any other edit. Neighbors move aside as the group grows.
 */
export function useGroupResize({
  getCurrentNodes,
  getLinks,
  setNodes,
  cardSize,
}: {
  getCurrentNodes: () => AppNode[]
  getLinks: () => Link[]
  setNodes: Dispatch<SetStateAction<AppNode[]>>
  cardSize: CardSize
}): GroupResize {
  const reactFlow = useReactFlow()
  const session = useRef<Session | null>(null)
  const setHandlesShown = useSetAtom(resizeHandlesAtom)

  const show = useCallback(
    (current: Session) => {
      const group = current.before.find((node) => node.id === current.id)
      const header = groupHeaderHeight(group && isCluster(group) ? group.data : undefined)
      const minimum = { width: cardSize.width + GROUP_PADDING * 2, height: cardSize.height + header + GROUP_PADDING }
      const delta = { x: (current.point.x - current.origin.x) / current.zoom, y: (current.point.y - current.origin.y) / current.zoom }
      const box = resizeBox(current.start, current.edges, delta, minimum)
      const sized = current.custom
        ? resizeCustomGroup(current.before, current.id, box, cardSize)
        : current.plan
          ? resizeAutoGroup(current.before, current.plan, current.id, current.start, box, current.edges, cardSize)
          : current.before
      const pushed = pushAside(current.before, sized, cardSize)

      // Saving and undo wait while a group is resizing, as they do for a drag.
      setNodes(pushed.map((node) => (node.id === current.id ? { ...node, resizing: !current.ended } : node)))
    },
    [setNodes, cardSize],
  )

  const start = useCallback(
    (groupId: string, edges: ResizeEdges, point: Point) => {
      const before = getCurrentNodes()
      const group = before.find((node) => node.id === groupId)

      if (!group || !isCluster(group)) return

      const custom = group.data.arrange === 'custom'
      const current: Session = {
        id: groupId,
        edges,
        origin: point,
        point,
        zoom: reactFlow.getZoom(),
        before,
        start: { ...group.position, ...sizeOf(group, cardSize) },
        custom,
        plan: custom ? null : undefined,
        frame: null,
        ended: false,
      }

      session.current = current
      // The handles stay on this group while it resizes, wherever the pointer goes.
      setHandlesShown(groupId)

      if (custom) return

      planReflow(before, getLinks(), groupId, cardSize)
        .catch((error: unknown) => {
          console.error('Could not plan the layout of group', groupId, error)

          return null
        })
        .then((plan) => {
          current.plan = plan

          // A resize that ended while its layout was planned still lands.
          if (current.ended || session.current === current) show(current)
        })
    },
    [getCurrentNodes, getLinks, reactFlow, cardSize, show, setHandlesShown],
  )

  const move = useCallback(
    (point: Point) => {
      const current = session.current

      if (!current) return

      current.point = point

      if (current.frame !== null) return

      current.frame = requestAnimationFrame(() => {
        current.frame = null

        if (session.current === current) show(current)
      })
    },
    [show],
  )

  const end = useCallback(() => {
    const current = session.current

    if (!current) return

    session.current = null
    current.ended = true

    if (current.frame !== null) cancelAnimationFrame(current.frame)

    if (current.plan !== undefined) show(current)
  }, [show])

  const active = useCallback(() => session.current !== null, [])

  return useMemo(() => ({ start, move, end, active }), [start, move, end, active])
}
