import { useEffect, type RefObject } from 'react'
import { useReactFlow, useStoreApi } from '@xyflow/react'
import { isTrackpadScroll } from './scrolling'

/** A pause this long between wheel events starts a new gesture, which is classified afresh. */
const GESTURE_GAP_MS = 150

/**
 * Zooms toward the pointer when a mouse wheel scrolls the canvas. Everything else falls
 * through to React Flow's pan on scroll, so a trackpad's two-finger scroll still pans and
 * pinch and ⌘-scroll still zoom.
 */
export function useWheelZoom(target: RefObject<HTMLElement | null>, enabled: boolean) {
  const reactFlow = useReactFlow()
  const store = useStoreApi()

  useEffect(() => {
    const element = target.current

    if (!enabled || !element) return

    let lastWheel = -Infinity
    let trackpad = false

    const onWheel = (event: WheelEvent) => {
      if (event.ctrlKey || event.metaKey) return

      const pane = event.target instanceof Element ? event.target.closest('.react-flow__renderer') : null

      if (!pane || (event.target as Element).closest('.nowheel')) return

      // Classifying once per gesture keeps momentum or an odd event from switching it midway.
      if (event.timeStamp - lastWheel > GESTURE_GAP_MS) trackpad = isTrackpadScroll(event)

      lastWheel = event.timeStamp

      if (trackpad) return

      event.preventDefault()
      event.stopPropagation()

      // The same curve d3-zoom uses for the wheel, keeping the point under the pointer still.
      const { minZoom, maxZoom } = store.getState()
      const { x, y, zoom } = reactFlow.getViewport()
      const step = event.deltaMode === WheelEvent.DOM_DELTA_LINE ? 0.05 : event.deltaMode === WheelEvent.DOM_DELTA_PAGE ? 1 : 0.002
      const nextZoom = Math.min(maxZoom, Math.max(minZoom, zoom * 2 ** (-event.deltaY * step)))
      const box = pane.getBoundingClientRect()
      const pointerX = event.clientX - box.left
      const pointerY = event.clientY - box.top
      const scale = nextZoom / zoom

      void reactFlow.setViewport({ x: pointerX - (pointerX - x) * scale, y: pointerY - (pointerY - y) * scale, zoom: nextZoom })
    }

    element.addEventListener('wheel', onWheel, { capture: true, passive: false })

    return () => element.removeEventListener('wheel', onWheel, { capture: true })
  }, [target, enabled, reactFlow, store])
}
