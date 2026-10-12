import { SKINS, skinOf } from './skins'
import { systemMotion, type Motion } from './motion'
import { saveSettings } from './settings'

export type ColorMode = 'light' | 'dark' | 'system'

export type Theme = {
  id: string
  label: string
  /** A theme with one scheme ignores the color mode. */
  schemes: readonly ('light' | 'dark')[]
}

/** Each theme's colors live in themes/<id>.css. The first one is the default and needs no attribute. */
export const THEMES: readonly Theme[] = [
  { id: 'classic', label: 'Classic', schemes: ['light', 'dark'] },
  { id: 'vibrant', label: 'Vibrant', schemes: ['dark'] },
]

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

export function themeOf(id: string): Theme {
  return THEMES.find((theme) => theme.id === id) ?? THEMES[0]
}

/** The color mode in effect, since a theme with one scheme overrides the chosen mode. */
export function colorModeOf(appearance: Appearance): ColorMode {
  const { schemes } = themeOf(appearance.theme)

  return schemes.length === 1 ? schemes[0] : appearance.colorMode
}

export function readAppearance(): Appearance {
  try {
    const mode = localStorage.getItem(COLOR_MODE_KEY)

    return {
      theme: themeOf(localStorage.getItem(THEME_KEY) ?? '').id,
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

export function applyAppearance(appearance: Appearance, root = document.documentElement) {
  if (appearance.theme === THEMES[0].id) delete root.dataset.theme
  else root.dataset.theme = appearance.theme

  if (appearance.skin === SKINS[0].id) delete root.dataset.skin
  else root.dataset.skin = appearance.skin

  if (appearance.colorMode === 'system') delete root.dataset.colorMode
  else root.dataset.colorMode = appearance.colorMode

  if (appearance.statusColors === 'theme') delete root.dataset.statusColors
  else root.dataset.statusColors = appearance.statusColors

  root.dataset.motion = motionOf(appearance)
}

/** The motion level in effect, the computer's when none is picked. */
export function motionOf(appearance: Appearance): Motion {
  return appearance.animations === 'system' ? systemMotion() : appearance.animations
}

/** Picks a motion level. Picking the one the computer asks for follows the computer again. */
export function withMotion(appearance: Appearance, motion: Motion): Appearance {
  return { ...appearance, animations: motion === systemMotion() ? 'system' : motion }
}
