import { GESTURES, type Gesture } from './keybindings'
import { saveSettings } from './settings'

/** What scrolling does on the canvas. A trackpad's two-finger scroll pans and pinch zooms either way. */
export type Scrolling = 'zoom' | 'pan'

export const SCROLLINGS: readonly { id: Scrolling; label: string; detail: string }[] = [
  { id: 'zoom', label: 'Zoom', detail: 'A mouse wheel zooms toward the pointer. Pan with a trackpad, Space-drag, middle-drag, or the Pan tool.' },
  { id: 'pan', label: 'Pan', detail: 'Scroll moves the canvas. Pinch or ⌘-scroll to zoom.' },
]

const SCROLLING_KEY = 'orion:scrolling'

export function readScrolling(): Scrolling {
  try {
    return localStorage.getItem(SCROLLING_KEY) === 'pan' ? 'pan' : 'zoom'
  } catch {
    return 'zoom'
  }
}

export function writeScrolling(scrolling: Scrolling) {
  saveSettings({ scrolling })
}

/** Every gesture, with panning and zooming described for what scrolling does. */
export function gesturesOf(scrolling: Scrolling): Gesture[] {
  return [
    { label: 'Pan', how: scrolling === 'pan' ? 'Middle-drag, Space-drag, or scroll' : 'Middle-drag, Space-drag, or trackpad scroll' },
    { label: 'Zoom', how: scrolling === 'zoom' ? 'Mouse wheel or pinch' : 'Pinch or ⌘-scroll' },
    ...GESTURES,
  ]
}

/**
 * Whether a wheel event most likely came from a trackpad rather than a mouse wheel. WebKit
 * and Chromium report a trackpad's legacy `wheelDeltaY` as -3 times `deltaY`, while a wheel
 * notch reports 120. Sideways movement only comes from trackpads and tilting wheels, which
 * both read better as panning.
 */
export function isTrackpadScroll(event: WheelEvent): boolean {
  const wheelDeltaY = (event as WheelEvent & { wheelDeltaY?: number }).wheelDeltaY

  if (event.deltaX !== 0) return true

  if (wheelDeltaY) return Math.abs(wheelDeltaY + 3 * event.deltaY) < 1

  // Without the legacy field, only trackpads scroll in pixels.
  return event.deltaMode === 0
}
