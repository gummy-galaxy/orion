import { SKINS, skinOf } from './skins'

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
  { id: 'conventional', label: 'Conventional', schemes: ['light', 'dark'] },
  { id: 'vibrant', label: 'Vibrant', schemes: ['dark'] },
]

export const COLOR_MODES: readonly ColorMode[] = ['light', 'dark', 'system']

export type Appearance = { theme: string; skin: string; colorMode: ColorMode }

// index.html reads these keys before the first paint, so keep them in step.
const THEME_KEY = 'orion:theme'
const SKIN_KEY = 'orion:skin'
const COLOR_MODE_KEY = 'orion:color-mode'

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
    }
  } catch {
    return { theme: THEMES[0].id, skin: SKINS[0].id, colorMode: 'system' }
  }
}

export function writeAppearance(appearance: Appearance) {
  try {
    localStorage.setItem(THEME_KEY, appearance.theme)
    localStorage.setItem(SKIN_KEY, appearance.skin)
    localStorage.setItem(COLOR_MODE_KEY, appearance.colorMode)
  } catch {
    // Only a remembered preference.
  }
}

export function applyAppearance(appearance: Appearance, root = document.documentElement) {
  if (appearance.theme === THEMES[0].id) delete root.dataset.theme
  else root.dataset.theme = appearance.theme

  if (appearance.skin === SKINS[0].id) delete root.dataset.skin
  else root.dataset.skin = appearance.skin

  if (appearance.colorMode === 'system') delete root.dataset.colorMode
  else root.dataset.colorMode = appearance.colorMode
}
