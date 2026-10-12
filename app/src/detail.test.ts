import { describe, expect, it } from 'vitest'
import { detailLevels, foldDepth, readDetail, shownLevel, stepDetail, writeDetail } from './detail'

const memory = () => {
  const values = new Map<string, string>()

  return {
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => void values.set(key, value),
    removeItem: (key: string) => void values.delete(key),
  }
}

describe('detail', () => {
  it('has one level per depth of groups, plus one with everything open', () => {
    expect(detailLevels([])).toBe(1)
    expect(detailLevels([0, 0])).toBe(2)
    expect(detailLevels([0, 1, 2, 1])).toBe(4)
  })

  it('shows every level when unset, and folds from the depth below the level shown', () => {
    expect(shownLevel(null, 3)).toBe(3)
    expect(shownLevel(5, 3)).toBe(3)
    expect(foldDepth(null, 3)).toBe(2)
    expect(foldDepth(1, 3)).toBe(0)
  })

  it('steps one level at a time, stays in range, and unsets at the top', () => {
    expect(stepDetail(null, 3, -1)).toBe(2)
    expect(stepDetail(2, 3, -1)).toBe(1)
    expect(stepDetail(1, 3, -1)).toBe(1)
    expect(stepDetail(1, 3, 1)).toBe(2)
    expect(stepDetail(2, 3, 1)).toBeNull()
    expect(stepDetail(null, 3, 1)).toBeNull()
  })

  it('remembers detail per workspace, and starts folded to one level', () => {
    const store = memory()

    expect(readDetail('orion', store)).toBe(1)
    writeDetail('orion', 2, store)
    expect(readDetail('orion', store)).toBe(2)
    expect(readDetail('other', store)).toBe(1)
    writeDetail('orion', null, store)
    expect(readDetail('orion', store)).toBeNull()
  })
})
