import { PRESETS } from './board'
import type { Gesture } from './types'

/** The named preset a gesture matches, if any. */
export function presetOf(gesture: Gesture) {
  return PRESETS.find(
    (preset) =>
      preset.gesture.leftDrag === gesture.leftDrag &&
      preset.gesture.rightDrag === gesture.rightDrag &&
      preset.gesture.modifiers === gesture.modifiers,
  )
}
