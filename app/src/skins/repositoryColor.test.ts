import { describe, expect, it } from 'vitest'
import { getRepositoryColorIndex } from './repositoryColor'

describe('repository chip color', () => {
  it('keeps the same repository on a stable palette entry', () => {
    expect(getRepositoryColorIndex('vocksel/orion')).toBe(3)
    expect(getRepositoryColorIndex('a')).toBe(1)
    expect(getRepositoryColorIndex('b')).toBe(2)
  })

  it('returns a palette entry for long repository names', () => {
    expect(getRepositoryColorIndex('a'.repeat(100))).toBeGreaterThanOrEqual(0)
    expect(getRepositoryColorIndex('a'.repeat(100))).toBeLessThan(4)
  })
})
