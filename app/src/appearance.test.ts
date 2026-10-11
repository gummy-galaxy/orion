import { beforeAll, describe, expect, it, vi } from 'vitest'
import { THEMES, applyAppearance, colorModeOf, themeOf, type Appearance, type Theme } from './appearance'
import { parseThemeFile } from './themeFile'

beforeAll(() => {
  // applyAppearance reads the computer's motion setting, which the test environment does not have.
  vi.stubGlobal('window', { matchMedia: () => ({ matches: false }) })
})

const base: Appearance = { theme: 'classic', colorMode: 'system', statusColors: 'theme', animations: 'system' }

/** A stand-in for the root element that records what applyAppearance sets on it. */
function fakeRoot() {
  const properties = new Map<string, string>()
  const dataset: Record<string, string> = {}
  const style = {
    setProperty: (name: string, value: string) => void properties.set(name, value),
    removeProperty: (name: string) => void properties.delete(name),
  }

  return { root: { dataset, style } as unknown as HTMLElement, properties, dataset }
}

const dusk = parseThemeFile(
  'dusk.json',
  JSON.stringify({
    light: { 'canvas.background': '#f6f1ea', 'status.done': '#2e7d4f', 'accent.default': '#b4481f' },
    dark: { 'canvas.background': '#1c1726', 'status.done': '#7fd9a8' },
  }),
)

const darkOnly = parseThemeFile('night.json', JSON.stringify({ dark: { 'canvas.background': '#000' } }))

describe('themeOf', () => {
  it('finds a shareable theme by id', () => {
    expect(themeOf('custom:dusk.json', [dusk])).toBe(dusk)
  })

  it('falls back to the default for an unknown id or a theme that failed to load', () => {
    const broken = parseThemeFile('bad.json', '{')

    expect(themeOf('custom:gone.json', [dusk]).id).toBe('classic')
    expect(themeOf('custom:bad.json', [broken]).id).toBe('classic')
  })
})

describe('colorModeOf', () => {
  it('follows a shareable theme with one scheme whatever the mode says', () => {
    expect(colorModeOf({ ...base, theme: 'custom:night.json', colorMode: 'light' }, [darkOnly])).toBe('dark')
    expect(colorModeOf({ ...base, theme: 'custom:dusk.json', colorMode: 'light' }, [dusk])).toBe('light')
  })
})

describe('applyAppearance', () => {
  it('leaves the built-in themes to their stylesheets', () => {
    const { root, properties, dataset } = fakeRoot()

    applyAppearance({ ...base, theme: 'vibrant' }, root, THEMES as Theme[])
    expect(dataset.theme).toBe('vibrant')
    expect(properties.size).toBe(0)

    applyAppearance(base, root, THEMES as Theme[])
    expect(dataset.theme).toBeUndefined()
    expect(properties.size).toBe(0)
  })

  it('sets a shareable theme on the root, with light-dark() where both schemes give a value', () => {
    const { root, properties, dataset } = fakeRoot()

    applyAppearance({ ...base, theme: 'custom:dusk.json' }, root, [dusk])

    expect(dataset.theme).toBeUndefined()
    expect(properties.get('--canvas-background')).toBe('light-dark(#f6f1ea, #1c1726)')
    expect(properties.get('--accent-default')).toBe('#b4481f')
    expect(properties.has('--text-primary')).toBe(false)
  })

  it('shows the one scheme a theme has', () => {
    const { root, properties } = fakeRoot()

    applyAppearance({ ...base, theme: 'custom:night.json' }, root, [darkOnly])

    expect(properties.get('--canvas-background')).toBe('#000')
    expect(properties.get('color-scheme')).toBe('dark')
  })

  it('leaves the status tokens to the colorblind sets', () => {
    const { root, properties } = fakeRoot()

    applyAppearance({ ...base, theme: 'custom:dusk.json', statusColors: 'red-green' }, root, [dusk])

    expect(properties.has('--status-done')).toBe(false)
    expect(properties.get('--canvas-background')).toBe('light-dark(#f6f1ea, #1c1726)')
  })

  it('clears a shareable theme when another theme is picked', () => {
    const { root, properties, dataset } = fakeRoot()

    applyAppearance({ ...base, theme: 'custom:night.json' }, root, [darkOnly])
    applyAppearance(base, root, [darkOnly])

    expect(properties.size).toBe(0)
    expect(dataset.theme).toBeUndefined()
  })

  it('falls back to the default when the chosen theme failed to load', () => {
    const { root, properties, dataset } = fakeRoot()

    applyAppearance({ ...base, theme: 'custom:bad.json' }, root, [parseThemeFile('bad.json', '{')])

    expect(properties.size).toBe(0)
    expect(dataset.theme).toBeUndefined()
  })
})
