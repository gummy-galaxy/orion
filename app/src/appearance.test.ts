import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { THEMES, applyAppearance, colorModeOf, readAppearance, themeOf, writeAppearance, type Appearance, type Theme } from './appearance'
import { TASK_HEIGHT, TASK_WIDTH } from './model'
import { SKINS, skinOf } from './skins'
import { parseThemeFile } from './themeFile'

const values = new Map<string, string>()

beforeEach(() => {
  values.clear()
  vi.stubGlobal('localStorage', {
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => values.set(key, value),
    removeItem: (key: string) => values.delete(key),
  })
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true }))
  vi.stubGlobal('window', { matchMedia: () => ({ matches: false }) })
})

afterEach(() => vi.unstubAllGlobals())

const base: Appearance = { theme: 'classic', skin: 'classic', colorMode: 'system', statusColors: 'theme', animations: 'system', companion: true }

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

    expect(themeOf('custom:gone.json', [dusk]).id).toBe('vibrant')
    expect(themeOf('custom:bad.json', [broken]).id).toBe('vibrant')
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

    // Classic's colors are the base on :root, so it needs no attribute.
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
    applyAppearance(base, root, THEMES as Theme[])

    expect(properties.size).toBe(0)
    expect(dataset.theme).toBeUndefined()
  })

  it('falls back to the default when the chosen theme failed to load', () => {
    const { root, properties, dataset } = fakeRoot()

    applyAppearance({ ...base, theme: 'custom:bad.json' }, root, [parseThemeFile('bad.json', '{')])

    expect(properties.size).toBe(0)
    expect(dataset.theme).toBe('vibrant')
  })
})

describe('card skins', () => {
  it('keeps Trading cards first and uses each skin size', () => {
    expect(SKINS.map((skin) => skin.id)).toEqual(['trading', 'classic', 'plain'])
    expect(SKINS.map((skin) => skin.size)).toEqual([
      { width: 198, height: 285 },
      { width: TASK_WIDTH, height: TASK_HEIGHT },
      { width: TASK_WIDTH, height: TASK_HEIGHT },
    ])
    expect(skinOf('unknown').id).toBe('trading')
    expect(skinOf('').id).toBe('trading')
  })

  it('deprecates every skin but Trading cards', () => {
    expect(SKINS.filter((skin) => 'deprecated' in skin).map((skin) => skin.id)).toEqual(['classic', 'plain'])
  })
})

describe('appearance', () => {
  it('defaults to Vibrant and Trading cards for new installs', () => {
    expect(readAppearance()).toEqual({
      theme: 'vibrant',
      skin: 'trading',
      colorMode: 'system',
      statusColors: 'theme',
      animations: 'system',
      companion: true,
    })
    expect(colorModeOf(readAppearance())).toBe('dark')
  })

  it('defaults an empty or unknown choice and keeps a deprecated one', () => {
    values.set('orion:theme', '')
    values.set('orion:skin', '')
    expect(readAppearance()).toMatchObject({ theme: 'vibrant', skin: 'trading' })

    values.set('orion:theme', 'custom:gone.json')
    values.set('orion:skin', 'unknown')
    expect(themeOf(readAppearance().theme).id).toBe('vibrant')
    expect(readAppearance().skin).toBe('trading')

    values.set('orion:theme', 'classic')
    values.set('orion:skin', 'classic')
    values.set('orion:color-mode', 'light')
    expect(readAppearance()).toMatchObject({ theme: 'classic', skin: 'classic', colorMode: 'light' })
    expect(colorModeOf(readAppearance())).toBe('light')
  })

  it('defaults invalid preferences while retaining valid ones', () => {
    values.set('orion:theme', 'classic')
    expect(readAppearance()).toEqual({
      theme: 'classic',
      skin: 'trading',
      colorMode: 'system',
      statusColors: 'theme',
      animations: 'system',
      companion: true,
    })

    values.set('orion:theme', 'vibrant')
    values.set('orion:skin', 'plain')
    values.set('orion:color-mode', 'dark')
    expect(readAppearance()).toEqual({
      theme: 'vibrant',
      skin: 'plain',
      colorMode: 'dark',
      statusColors: 'theme',
      animations: 'system',
      companion: true,
    })

    values.set('orion:skin', 'unknown')
    values.set('orion:color-mode', 'invalid')
    expect(readAppearance()).toEqual({
      theme: 'vibrant',
      skin: 'trading',
      colorMode: 'system',
      statusColors: 'theme',
      animations: 'system',
      companion: true,
    })

    values.set('orion:skin', 'classic')
    expect(readAppearance()).toEqual({
      theme: 'vibrant',
      skin: 'classic',
      colorMode: 'system',
      statusColors: 'theme',
      animations: 'system',
      companion: true,
    })
  })

  it('writes theme, skin, and color mode as separate preferences', () => {
    const appearance: Appearance = {
      theme: 'vibrant',
      skin: 'plain',
      colorMode: 'light',
      statusColors: 'theme',
      animations: 'system',
      companion: true,
    }

    writeAppearance(appearance)

    expect(values).toEqual(
      new Map([
        ['orion:theme', 'vibrant'],
        ['orion:skin', 'plain'],
        ['orion:color-mode', 'light'],
        ['orion:status-colors', 'theme'],
      ]),
    )
    expect(colorModeOf(appearance)).toBe('dark')
  })

  it('remembers a hidden companion and forgets the default', () => {
    const appearance: Appearance = {
      theme: 'classic',
      skin: 'classic',
      colorMode: 'system',
      statusColors: 'theme',
      animations: 'system',
      companion: false,
    }

    writeAppearance(appearance)
    expect(values.get('orion:companion')).toBe('off')
    expect(readAppearance().companion).toBe(false)

    writeAppearance({ ...appearance, companion: true })
    expect(values.has('orion:companion')).toBe(false)
    expect(readAppearance().companion).toBe(true)
  })

  it('applies nondefault attributes and clears them for defaults', () => {
    const { root, dataset } = fakeRoot()

    applyAppearance({ theme: 'vibrant', skin: 'plain', colorMode: 'dark', statusColors: 'theme', animations: 'system', companion: true }, root)
    expect(dataset).toEqual({ theme: 'vibrant', skin: 'plain', colorMode: 'dark', motion: 'on' })

    applyAppearance({ theme: 'classic', skin: 'trading', colorMode: 'system', statusColors: 'theme', animations: 'system', companion: true }, root)
    expect(dataset).toEqual({ motion: 'on' })
  })

  it('falls back when storage is unavailable', () => {
    vi.stubGlobal('localStorage', {
      getItem: () => {
        throw new Error('unavailable')
      },
    })
    expect(readAppearance()).toEqual({
      theme: 'vibrant',
      skin: 'trading',
      colorMode: 'system',
      statusColors: 'theme',
      animations: 'system',
      companion: true,
    })
  })
})
