import { describe, expect, it } from 'vitest'
import { MAX_ZOOM, MIN_ZOOM, OPEN_ZOOM, mapViewportForCardSize, openGroupViewport, readViewport, writeViewport } from './viewport'

const classicSize = { width: 216, height: 72 }
const largeSize = { width: 288, height: 400 }

const memory = () => {
  const items = new Map<string, string>()

  return { getItem: (key: string) => items.get(key) ?? null, setItem: (key: string, value: string) => void items.set(key, value) }
}

describe('viewport storage', () => {
  it('remembers each workspace separately', () => {
    const store = memory()

    writeViewport('default', { x: 10, y: -20, zoom: 0.5 }, store)
    writeViewport('work', { x: 1, y: 2, zoom: 1.5 }, store)
    expect(readViewport('default', store)).toEqual({ x: 10, y: -20, zoom: 0.5 })
    expect(readViewport('work', store)).toEqual({ x: 1, y: 2, zoom: 1.5 })
    expect(readViewport('other', store)).toBe(null)
  })

  it('ignores unusable values', () => {
    const store = memory()

    store.setItem('orion:viewport:broken', '{not json')
    store.setItem('orion:viewport:flat', JSON.stringify({ x: 0, y: 0, zoom: 0 }))
    store.setItem('orion:viewport:partial', JSON.stringify({ x: 0, zoom: 1 }))
    writeViewport('nan', { x: NaN, y: 0, zoom: 1 }, store)

    for (const name of ['broken', 'flat', 'partial', 'nan']) expect(readViewport(name, store)).toBe(null)
  })

  it('keeps working without storage', () => {
    expect(readViewport('default', null)).toBe(null)
    expect(() => writeViewport('default', { x: 0, y: 0, zoom: 1 }, null)).not.toThrow()
  })
})

describe('viewport card size mapping', () => {
  const box = { width: 1200, height: 800 }

  it('keeps the displayed center on the same mapped world point', () => {
    const original = { x: -600, y: -1200, zoom: 0.8 }
    const mapped = mapViewportForCardSize(original, box, classicSize, largeSize)
    const originalWorld = { x: (box.width / 2 - original.x) / original.zoom, y: (box.height / 2 - original.y) / original.zoom }
    const mappedWorld = { x: (box.width / 2 - mapped.x) / mapped.zoom, y: (box.height / 2 - mapped.y) / mapped.zoom }

    expect(mappedWorld.x).toBeCloseTo(originalWorld.x * (344 / 272), 9)
    expect(mappedWorld.y).toBeCloseTo(originalWorld.y * (424 / 96), 9)
    expect(mapped.zoom).toBeCloseTo(original.zoom / Math.sqrt((344 / 272) * (424 / 96)), 9)
  })

  it('keeps the center when zoom is clamped', () => {
    const viewport = { x: -600, y: -1200, zoom: MIN_ZOOM }
    const enlarged = mapViewportForCardSize(viewport, box, classicSize, largeSize)
    const reduced = mapViewportForCardSize({ ...viewport, zoom: MAX_ZOOM }, box, largeSize, classicSize)

    expect(enlarged.zoom).toBe(MIN_ZOOM)
    expect(reduced.zoom).toBe(MAX_ZOOM)
    expect((box.width / 2 - enlarged.x) / enlarged.zoom).toBeCloseTo(((box.width / 2 - viewport.x) / viewport.zoom) * (344 / 272), 9)
  })
})

describe('openGroupViewport', () => {
  const screen = { width: 1000, height: 800 }
  const margin = { x: 170, y: 90 }

  it('centers a group that fits, at the same zoom as any other', () => {
    const viewport = openGroupViewport({ x: 100, y: 200, width: 400, height: 300 }, screen, margin)

    expect(viewport.zoom).toBe(OPEN_ZOOM)
    expect(viewport.x + (100 + 200) * viewport.zoom).toBe(screen.width / 2)
    expect(viewport.y + (200 + 150) * viewport.zoom).toBe(screen.height / 2)
  })

  it('opens a group too big to fit on its top-left corner, past the margin', () => {
    const viewport = openGroupViewport({ x: 100, y: 200, width: 5000, height: 3000 }, screen, margin)

    expect(viewport.zoom).toBe(OPEN_ZOOM)
    expect(viewport.x + 100 * viewport.zoom).toBe(margin.x * viewport.zoom)
    expect(viewport.y + 200 * viewport.zoom).toBe(margin.y * viewport.zoom)
  })

  it('handles each axis on its own', () => {
    const viewport = openGroupViewport({ x: 0, y: 0, width: 5000, height: 300 }, screen, margin)

    expect(viewport.x).toBe(margin.x * viewport.zoom)
    expect(viewport.y + 150 * viewport.zoom).toBe(screen.height / 2)
  })
})
