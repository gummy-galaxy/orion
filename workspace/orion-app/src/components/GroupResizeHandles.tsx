import { memo, useContext, type PointerEvent } from 'react'
import { ActionsContext } from '../derive'
import type { ResizeEdges } from '../resize/types'

const HANDLES: { name: string; edges: ResizeEdges }[] = [
  { name: 'n', edges: { top: true } },
  { name: 's', edges: { bottom: true } },
  { name: 'e', edges: { right: true } },
  { name: 'w', edges: { left: true } },
  { name: 'ne', edges: { top: true, right: true } },
  { name: 'nw', edges: { top: true, left: true } },
  { name: 'se', edges: { bottom: true, right: true } },
  { name: 'sw', edges: { bottom: true, left: true } },
]

const pointOf = (event: PointerEvent) => ({ x: event.clientX, y: event.clientY })

/** The edges and corners a group is resized by, like a window's. */
export const GroupResizeHandles = memo(function GroupResizeHandles({ id }: { id: string }) {
  const { resizeGroup } = useContext(ActionsContext)!

  return HANDLES.map(({ name, edges }) => (
    <div
      key={name}
      className={`group-resize group-resize-${name} nodrag nopan`}
      onPointerDown={(event) => {
        if (event.button !== 0) return

        event.stopPropagation()
        event.currentTarget.setPointerCapture(event.pointerId)
        resizeGroup.start(id, edges, pointOf(event))
      }}
      onPointerMove={(event) => {
        if (event.currentTarget.hasPointerCapture(event.pointerId)) resizeGroup.move(pointOf(event))
      }}
      // Capture ends when the pointer lifts or the system takes it, so the resize ends there either way.
      onLostPointerCapture={() => resizeGroup.end()}
    />
  ))
})
