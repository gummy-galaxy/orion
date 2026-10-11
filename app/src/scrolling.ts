import { GESTURES, type Gesture } from './keybindings'
import { saveSettings } from './settings'

/** What scrolling does on the canvas. Pinch zooms either way. */
export type Scrolling = 'zoom' | 'pan'

export const SCROLLINGS: readonly { id: Scrolling; label: string; detail: string }[] = [
  { id: 'zoom', label: 'Zoom', detail: 'Scroll zooms toward the pointer. Pan with Space-drag, middle-drag, or the Pan tool.' },
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
    { label: 'Pan', how: scrolling === 'pan' ? 'Middle-drag, Space-drag, or scroll' : 'Middle-drag or Space-drag' },
    { label: 'Zoom', how: scrolling === 'zoom' ? 'Scroll or pinch' : 'Pinch or ⌘-scroll' },
    ...GESTURES,
  ]
}
