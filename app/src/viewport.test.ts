import { describe, expect, it } from 'vitest'
import { readViewport, writeViewport } from './viewport'

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
