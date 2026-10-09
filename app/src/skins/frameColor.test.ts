import { describe, expect, it } from 'vitest'
import { getFramePalette } from './frameColor'

describe('getFramePalette', () => {
  it('keeps a repository color stable across card kinds', () => {
    expect(getFramePalette('vocksel/orion', 'step')).toBe(getFramePalette('vocksel/orion', 'pr'))
  })

  it('uses the kind when a repository is absent', () => {
    expect(getFramePalette(undefined, 'gate')).toBe(getFramePalette('', 'gate'))
    expect(getFramePalette(undefined, 'gate')).toBeGreaterThanOrEqual(0)
    expect(getFramePalette(undefined, 'gate')).toBeLessThan(6)
  })
})
