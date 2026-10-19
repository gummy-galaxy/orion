import { SKINS, skinOf } from './skins'
import { systemMotion, type Motion } from './motion'
import { saveSettings } from './settings'
import { TOKENS } from './tokens'

export type ColorMode = 'light' | 'dark' | 'system'

export type Scheme = 'light' | 'dark'

export type Theme = {
  id: string
  label: string
  /** A theme with one scheme ignores the color mode. */
  schemes: readonly Scheme[]
  /** A shareable theme's token values by scheme, keyed by token name. Built-in themes read their colors from CSS and leave this out. */
  values?: Partial<Record<Scheme, Record<string, string>>>
  /** Who made a shareable theme, from its file. */
  author?: string
  /** Why a shareable theme file could not be used. The theme is listed, but it cannot be picked. */
  error?: string
  /** Problems that did not stop a shareable theme, such as tokens it does not name. */
  notes?: string[]
  /** A built-in theme that still works but is slated for removal. Settings tags it. */
  deprecated?: boolean
}

/**
 * Each built-in theme's colors live in themes/<id>.css. The first one is the default, for anyone who hasn't picked a
 * theme or whose pick is gone.
 */
export const THEMES: readonly Theme[] = [
  { id: 'vibrant', label: 'Vibrant', schemes: ['dark'] },
  { id: 'classic', label: 'Classic', schemes: ['light', 'dark'], deprecated: true },
]

/** Classic's colors sit on :root, under every other theme and theme file, so it needs no attribute. */
const BASE_THEME = 'classic'

export const COLOR_MODES: readonly ColorMode[] = ['light', 'dark', 'system']

export type StatusColors = 'theme' | 'red-green' | 'blue-yellow'

/** Colorblind status colors live in themes/colorblind.css and layer over any theme. */
export const STATUS_COLORS: readonly { id: StatusColors; label: string }[] = [
  { id: 'theme', label: 'Off' },
  { id: 'red-green', label: 'Red-green' },
  { id: 'blue-yellow', label: 'Blue-yellow' },
]

/** A motion level picked in Accessibility, or the computer's until one is. */
export type Animations = 'system' | Motion

export const ANIMATIONS: readonly { id: Motion; label: string }[] = [
  { id: 'on', label: 'On' },
  { id: 'reduced', label: 'Reduced' },
  { id: 'off', label: 'Off' },
]

export type Appearance = {
  theme: string
  skin: string
  colorMode: ColorMode
  statusColors: StatusColors
  animations: Animations
  /** Whether the star companion perches on the canvas. */
  companion: boolean
}

// index.html reads these keys before the first paint, so keep them in step.
const THEME_KEY = 'orion:theme'
const SKIN_KEY = 'orion:skin'
const COLOR_MODE_KEY = 'orion:color-mode'
const STATUS_COLORS_KEY = 'orion:status-colors'
const ANIMATIONS_KEY = 'orion:animations'
const COMPANION_KEY = 'orion:companion'

/** The theme with this id. An unknown id, or a shareable theme that failed to load, falls back to the default. */
export function themeOf(id: string, themes: readonly Theme[] = THEMES): Theme {
  return themes.find((theme) => theme.id === id && !theme.error) ?? THEMES[0]
}

/** The color mode in effect, since a theme with one scheme overrides the chosen mode. */
export function colorModeOf(appearance: Appearance, themes: readonly Theme[] = THEMES): ColorMode {
  const { schemes } = themeOf(appearance.theme, themes)

  return schemes.length === 1 ? schemes[0] : appearance.colorMode
}

export function readAppearance(): Appearance {
  try {
    const mode = localStorage.getItem(COLOR_MODE_KEY)

    return {
      // Kept as saved, even when its file is gone; applyAppearance falls back to the default.
      theme: localStorage.getItem(THEME_KEY) || THEMES[0].id,
      skin: skinOf(localStorage.getItem(SKIN_KEY) ?? '').id,
      colorMode: mode === 'light' || mode === 'dark' ? mode : 'system',
      statusColors: STATUS_COLORS.find((option) => option.id === localStorage.getItem(STATUS_COLORS_KEY))?.id ?? 'theme',
      animations: ANIMATIONS.find((option) => option.id === localStorage.getItem(ANIMATIONS_KEY))?.id ?? 'system',
      companion: localStorage.getItem(COMPANION_KEY) !== 'off',
    }
  } catch {
    return { theme: THEMES[0].id, skin: SKINS[0].id, colorMode: 'system', statusColors: 'theme', animations: 'system', companion: true }
  }
}

export function writeAppearance(appearance: Appearance) {
  saveSettings({
    theme: appearance.theme,
    skin: appearance.skin,
    'color-mode': appearance.colorMode,
    'status-colors': appearance.statusColors,
    animations: appearance.animations === 'system' ? null : appearance.animations,
    companion: appearance.companion ? null : 'off',
  })
}

export function applyAppearance(appearance: Appearance, root = document.documentElement, themes: readonly Theme[] = THEMES) {
  const theme = themeOf(appearance.theme, themes)

  // A shareable theme sets its values on the root instead, so it needs no attribute.
  if (theme.id === BASE_THEME || theme.values) delete root.dataset.theme
  else root.dataset.theme = theme.id

  if (appearance.skin === SKINS[0].id) delete root.dataset.skin
  else root.dataset.skin = appearance.skin

  if (appearance.colorMode === 'system') delete root.dataset.colorMode
  else root.dataset.colorMode = appearance.colorMode

  if (appearance.statusColors === 'theme') delete root.dataset.statusColors
  else root.dataset.statusColors = appearance.statusColors

  applyThemeValues(theme, appearance.statusColors, root)

  root.dataset.motion = motionOf(appearance)
}

/**
 * Sets a shareable theme's token values on the root, over the stylesheets. A token with a value for both
 * schemes uses light-dark(), so the color mode still picks one. Status tokens are left to the colorblind
 * sets, which layer over every theme.
 */
function applyThemeValues(theme: Theme, statusColors: StatusColors, root: HTMLElement) {
  for (const token of TOKENS) root.style.removeProperty(token.cssVar)

  root.style.removeProperty('color-scheme')

  if (!theme.values) return

  for (const token of TOKENS) {
    if (token.group === 'status' && statusColors !== 'theme') continue

    const light = theme.values.light?.[token.name]
    const dark = theme.values.dark?.[token.name]
    const value = light && dark ? `light-dark(${light}, ${dark})` : (light ?? dark)

    if (value) root.style.setProperty(token.cssVar, value)
  }

  // A theme with one scheme shows that scheme whatever the color mode says.
  if (theme.schemes.length === 1) root.style.setProperty('color-scheme', theme.schemes[0])
}

/** The motion level in effect, the computer's when none is picked. */
export function motionOf(appearance: Appearance): Motion {
  return appearance.animations === 'system' ? systemMotion() : appearance.animations
}

/** Picks a motion level. Picking the one the computer asks for follows the computer again. */
export function withMotion(appearance: Appearance, motion: Motion): Appearance {
  return { ...appearance, animations: motion === systemMotion() ? 'system' : motion }
}
