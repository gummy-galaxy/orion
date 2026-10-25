import { TOKENS } from './tokens'

/**
 * A cover or background stored as an image is an asset id: a lowercase name with an image extension, as the
 * CLI and `importImage` write them. Anything else in a background is a hex color or a color token name.
 */
const ASSET_ID = /^[a-z0-9-]+\.(png|jpg|gif|webp)$/
const HEX_COLOR = /^#(?:[0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})$/i

/** Below this zoom a header's text is too small to read, so it folds away. Canvas and group headers share it. */
export const HEADER_MIN_ZOOM = 0.8

/** A canvas's own cover, background, and header, saved in the workspace settings beside its sources. */
export type CanvasStyle = { cover?: string; background?: string; header?: string }

/** A change to a canvas or group style: `null` clears a setting, and an absent key keeps it. */
export type StyleChange = { cover?: string | null; background?: string | null; header?: string | null }

/** What a group paints behind its contents. Each layer is optional, so a group with none looks stock. */
export type GroupLayers = { color?: string; backdrop?: string; cover?: string }

/** The header text to show, or undefined when there is none or it is only whitespace. */
export function headerText(value: string | undefined): string | undefined {
  const text = value?.trim()

  return text ? text : undefined
}

export const isAssetId = (value: string | undefined): boolean => value !== undefined && ASSET_ID.test(value)

/** The CSS color a background stands for, or undefined to fall back to the stock look. */
export function backgroundColor(value: string | undefined): string | undefined {
  if (!value || isAssetId(value)) return undefined

  if (value.startsWith('#')) return HEX_COLOR.test(value) ? value : undefined

  const token = TOKENS.find((entry) => entry.group === 'color' && entry.name === value)

  return token ? `var(${token.cssVar})` : undefined
}

/** Reads a canvas's cover and background from the settings the server returns. Other values are ignored. */
export function readCanvasStyle(settings: Record<string, unknown> | undefined): CanvasStyle {
  const style: CanvasStyle = {}

  if (typeof settings?.cover === 'string' && isAssetId(settings.cover)) style.cover = settings.cover

  if (typeof settings?.background === 'string' && settings.background) style.background = settings.background

  if (typeof settings?.header === 'string' && settings.header.trim()) style.header = settings.header

  return style
}

/** Applies a change: an absent key keeps the setting, and `null` clears it. */
export function applyStyleChange<T extends CanvasStyle>(current: T, change: StyleChange): T {
  const next = { ...current }

  if (change.cover !== undefined) {
    if (change.cover === null) delete next.cover
    else next.cover = change.cover
  }

  if (change.background !== undefined) {
    if (change.background === null) delete next.background
    else next.background = change.background
  }

  if (change.header !== undefined) {
    if (change.header === null) delete next.header
    else next.header = change.header
  }

  return next
}

/** Which layers a group paints. Collapsed groups show only their color, since their cover would not fit the card. */
export function groupLayers(style: { cover?: string; background?: string }, collapsed: boolean): GroupLayers {
  const layers: GroupLayers = {}
  const color = backgroundColor(style.background)

  if (color) layers.color = color

  if (isAssetId(style.background)) layers.backdrop = style.background

  if (!collapsed && isAssetId(style.cover)) layers.cover = style.cover

  return layers
}
