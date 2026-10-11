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

export type Appearance = { theme: string; colorMode: ColorMode; statusColors: StatusColors }

// index.html reads these keys before the first paint, so keep the two in step.
const THEME_KEY = 'orion:theme'
const COLOR_MODE_KEY = 'orion:color-mode'
const STATUS_COLORS_KEY = 'orion:status-colors'

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
      colorMode: mode === 'light' || mode === 'dark' ? mode : 'system',
      statusColors: STATUS_COLORS.find((option) => option.id === localStorage.getItem(STATUS_COLORS_KEY))?.id ?? 'theme',
    }
  } catch {
    return { theme: THEMES[0].id, colorMode: 'system', statusColors: 'theme' }
  }
}

export function writeAppearance(appearance: Appearance) {
  try {
    localStorage.setItem(THEME_KEY, appearance.theme)
    localStorage.setItem(COLOR_MODE_KEY, appearance.colorMode)
    localStorage.setItem(STATUS_COLORS_KEY, appearance.statusColors)
  } catch {
    // Only a remembered preference.
  }
}

export function applyAppearance(appearance: Appearance, root = document.documentElement) {
  if (appearance.theme === THEMES[0].id) delete root.dataset.theme
  else root.dataset.theme = appearance.theme

  if (appearance.colorMode === 'system') delete root.dataset.colorMode
  else root.dataset.colorMode = appearance.colorMode

  if (appearance.statusColors === 'theme') delete root.dataset.statusColors
  else root.dataset.statusColors = appearance.statusColors
}
