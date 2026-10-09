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
  })
})

afterEach(() => vi.unstubAllGlobals())

describe('card skins', () => {
  it('keeps Classic first and all skins at the current card size', () => {
    expect(SKINS.map((skin) => skin.id)).toEqual(['classic', 'plain', 'trello'])
    expect(SKINS.map((skin) => skin.size)).toEqual([
      { width: TASK_WIDTH, height: TASK_HEIGHT },
      { width: TASK_WIDTH, height: TASK_HEIGHT },
      { width: TASK_WIDTH, height: TASK_HEIGHT },
    ])
    expect(skinOf('unknown')).toBe(SKINS[0])
  })
})

describe('appearance', () => {
  it('defaults invalid preferences while retaining valid ones', () => {
    expect(readAppearance()).toEqual({ theme: 'classic', skin: 'classic', colorMode: 'system' })

    values.set('orion:theme', 'vibrant')
    values.set('orion:skin', 'plain')
    values.set('orion:color-mode', 'dark')
    expect(readAppearance()).toEqual({ theme: 'vibrant', skin: 'plain', colorMode: 'dark' })

    values.set('orion:skin', 'unknown')
    values.set('orion:color-mode', 'invalid')
    expect(readAppearance()).toEqual({ theme: 'vibrant', skin: 'classic', colorMode: 'system' })
  })

  it('writes theme, skin, and color mode as separate local preferences', () => {
    const appearance: Appearance = { theme: 'vibrant', skin: 'plain', colorMode: 'light' }

    writeAppearance(appearance)

    expect(values).toEqual(
      new Map([
        ['orion:theme', 'vibrant'],
        ['orion:skin', 'plain'],
        ['orion:color-mode', 'light'],
      ]),
    )
    expect(colorModeOf(appearance)).toBe('dark')
  })

  it('applies nondefault attributes and clears them for defaults', () => {
    const root = { dataset: {} as DOMStringMap } as HTMLElement

    applyAppearance({ theme: 'vibrant', skin: 'plain', colorMode: 'dark' }, root)
    expect(root.dataset).toEqual({ theme: 'vibrant', skin: 'plain', colorMode: 'dark' })

    applyAppearance({ theme: 'classic', skin: 'classic', colorMode: 'system' }, root)
    expect(root.dataset).toEqual({})
  })

  it('falls back when storage is unavailable', () => {
    vi.stubGlobal('localStorage', {
      getItem: () => {
        throw new Error('unavailable')
      },
    })
    expect(readAppearance()).toEqual({ theme: 'classic', skin: 'classic', colorMode: 'system' })
  })
})
