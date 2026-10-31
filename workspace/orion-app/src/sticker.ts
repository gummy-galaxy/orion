import { absolutePosition, type AppNode } from './model'

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
export const loadoutOf = (saved?: Loadout | null) =>
  Array.from({ length: WHEEL_SLOTS }, (_, i) => (saved ? (saved[i] ?? null) : STARTER[i]))

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
    '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32">' +
      `<text x="16" y="17" font-size="24" text-anchor="middle" dominant-baseline="middle">${emoji}</text></svg>`,
  )}") 16 16, crosshair`

/**
 * Half a sticker's size on the canvas, which is how far its box reaches from its center when a selection box picks it
 * up.
 */
export const STICKER_HALF_SIZE = 20

/**
 * The stickers picked after pressing one. A plain press picks it alone unless it's already picked, which keeps a
 * selection together to drag. ⇧ or ⌘ toggles it.
 */
export function pressedStickers(picked: ReadonlySet<string>, id: string, additive: boolean): ReadonlySet<string> {
  if (!additive) return picked.has(id) ? picked : new Set([id])

  const next = new Set(picked)

  if (next.has(id)) next.delete(id)
  else next.add(id)

  return next
}

/**
 * Where each loose sticker sits from `anchor`, so it can keep that spot while the anchor moves. Stickers on a card or
 * group are left out, since those move with it already.
 */
export function offsetsFrom(anchor: { x: number; y: number }, stickers: Sticker[]) {
  return new Map(
    stickers
      .filter((sticker) => !sticker.on)
      .map((sticker) => [sticker.id, { x: sticker.x - anchor.x, y: sticker.y - anchor.y }]),
  )
}

/**
 * Where each sticker shows: a loose one where it is, one on a card or group moved along with it, and none while that
 * card or group is hidden.
 */
export function placeStickers(stickers: Sticker[], map: Map<string, AppNode>, hidden: ReadonlySet<string>) {
  return stickers.flatMap((sticker) => {
    if (!sticker.on) return [sticker]

    const node = map.get(sticker.on)

    if (!node || hidden.has(node.id)) return []

    const position = absolutePosition(node, map)

    return [{ ...sticker, x: position.x + sticker.x, y: position.y + sticker.y }]
  })
}
