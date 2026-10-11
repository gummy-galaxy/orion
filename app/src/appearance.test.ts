import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { applyAppearance, colorModeOf, readAppearance, writeAppearance, type Appearance } from './appearance'
import { TASK_HEIGHT, TASK_WIDTH } from './model'
import { SKINS, skinOf } from './skins'

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

describe('card skins', () => {
  it('keeps Classic first and uses each skin size', () => {
    expect(SKINS.map((skin) => skin.id)).toEqual(['classic', 'plain', 'trading'])
    expect(SKINS.map((skin) => skin.size)).toEqual([
      { width: TASK_WIDTH, height: TASK_HEIGHT },
      { width: TASK_WIDTH, height: TASK_HEIGHT },
      { width: 264, height: 380 },
    ])
    expect(skinOf('unknown')).toBe(SKINS[0])
  })
})

describe('appearance', () => {
  it('defaults invalid preferences while retaining valid ones', () => {
    expect(readAppearance()).toEqual({ theme: 'classic', skin: 'classic', colorMode: 'system', statusColors: 'theme', animations: 'system' })

    values.set('orion:theme', 'vibrant')
    values.set('orion:skin', 'plain')
    values.set('orion:color-mode', 'dark')
    expect(readAppearance()).toEqual({ theme: 'vibrant', skin: 'plain', colorMode: 'dark', statusColors: 'theme', animations: 'system' })

    values.set('orion:skin', 'unknown')
    values.set('orion:color-mode', 'invalid')
    expect(readAppearance()).toEqual({ theme: 'vibrant', skin: 'classic', colorMode: 'system', statusColors: 'theme', animations: 'system' })

    values.set('orion:skin', 'trading')
    expect(readAppearance()).toEqual({ theme: 'vibrant', skin: 'trading', colorMode: 'system', statusColors: 'theme', animations: 'system' })
  })

  it('writes theme, skin, and color mode as separate preferences', () => {
    const appearance: Appearance = { theme: 'vibrant', skin: 'plain', colorMode: 'light', statusColors: 'theme', animations: 'system' }

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

  it('applies nondefault attributes and clears them for defaults', () => {
    const root = { dataset: {} as DOMStringMap } as HTMLElement

    applyAppearance({ theme: 'vibrant', skin: 'plain', colorMode: 'dark', statusColors: 'theme', animations: 'system' }, root)
    expect(root.dataset).toEqual({ theme: 'vibrant', skin: 'plain', colorMode: 'dark', motion: 'on' })

    applyAppearance({ theme: 'classic', skin: 'classic', colorMode: 'system', statusColors: 'theme', animations: 'system' }, root)
    expect(root.dataset).toEqual({ motion: 'on' })
  })

  it('falls back when storage is unavailable', () => {
    vi.stubGlobal('localStorage', {
      getItem: () => {
        throw new Error('unavailable')
      },
    })
    expect(readAppearance()).toEqual({ theme: 'classic', skin: 'classic', colorMode: 'system', statusColors: 'theme', animations: 'system' })
  })
})
