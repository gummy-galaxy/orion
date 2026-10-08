/**
 * A sticker stamped on the canvas. `kind` is its emoji. `x` and `y` are its
 * center: relative to the top-left of the card or group it sits `on`, so it
 * moves with that, or in canvas coordinates when it sits on nothing.
 */
export type Sticker = { id: string; kind: string; x: number; y: number; tilt: number; on?: string }

/** The wheel's slots, clockwise from the top. An empty slot is null. */
export type Loadout = (string | null)[]

export const WHEEL_SLOTS = 8
export const FALLBACK_STICKER = '🎉'
const STARTER: Loadout = ['🎉', '🔥', '👀', '❤️', '🚀', '✅', '⭐', '👍']

/** A saved loadout, padded or trimmed to the wheel; files without one get the starter set. */
export const loadoutOf = (saved?: Loadout | null) => Array.from({ length: WHEEL_SLOTS }, (_, i) => (saved ? (saved[i] ?? null) : STARTER[i]))

const EMOJI_PATTERN = /\p{Extended_Pictographic}|\p{Regional_Indicator}|\u20e3/u
const graphemes = new Intl.Segmenter(undefined, { granularity: 'grapheme' })

/** The first emoji in some typed or pasted text. */
export function firstEmoji(text: string): string | null {
  for (const { segment } of graphemes.segment(text)) if (EMOJI_PATTERN.test(segment)) return segment

  return null
}

/** A cursor that shows the sticker about to be stamped. */
export const stickerCursor = (emoji: string) =>
  `url("data:image/svg+xml,${encodeURIComponent(
    `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><text x="16" y="17" font-size="24" text-anchor="middle" dominant-baseline="middle">${emoji}</text></svg>`,
  )}") 16 16, crosshair`
