/**
 * A sticker stamped on the canvas. `x` and `y` are its center: relative to the
 * top-left of the card or group it sits `on`, so it moves with that, or in
 * canvas coordinates when it sits on nothing.
 */
export type Sticker = { id: string; kind: string; x: number; y: number; tilt: number; on?: string }

export type StickerKind = { id: string; emoji: string; label: string }

/** The wheel's stickers, clockwise from the top. */
export const STICKERS: StickerKind[] = [
  { id: 'party', emoji: '🎉', label: 'Shipped' },
  { id: 'fire', emoji: '🔥', label: 'Hot' },
  { id: 'eyes', emoji: '👀', label: 'Watching' },
  { id: 'heart', emoji: '❤️', label: 'Love' },
  { id: 'rocket', emoji: '🚀', label: 'Launch' },
  { id: 'check', emoji: '✅', label: 'Done' },
  { id: 'star', emoji: '⭐', label: 'Star' },
  { id: 'thumbs', emoji: '👍', label: 'Nice' },
]

export const stickerKind = (id: string) => STICKERS.find((s) => s.id === id) ?? STICKERS[0]

/** A cursor that shows the sticker about to be stamped. */
export const stickerCursor = (id: string) =>
  `url("data:image/svg+xml,${encodeURIComponent(
    `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><text x="16" y="17" font-size="24" text-anchor="middle" dominant-baseline="middle">${stickerKind(id).emoji}</text></svg>`,
  )}") 16 16, crosshair`
