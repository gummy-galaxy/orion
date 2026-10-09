import { DitheringShapes } from '@paper-design/shaders'
import { describe, expect, it } from 'vitest'
import { getCardArtSpec } from './artSpec'
import { INK } from './frameColor'

const inks = [INK.violet, INK.pink] as const

describe('getCardArtSpec', () => {
  it('is deterministic for a seed, kind, and inks', () => {
    const spec = getCardArtSpec('card-42', 'pr', inks)

    expect(spec).toEqual(getCardArtSpec('card-42', 'pr', inks))
    expect(spec.back[0]).toMatch(/^rgb\(\d+ \d+ \d+\)$/)
    expect(getCardArtSpec('card-42', 'pr', inks)).not.toEqual(getCardArtSpec('card-43', 'pr', inks))
  })

  it('uses the study shape families', () => {
    expect([DitheringShapes.warp, DitheringShapes.simplex, DitheringShapes.swirl]).toContain(getCardArtSpec('one', 'pr', inks).base.u_shape)
    expect([DitheringShapes.wave, DitheringShapes.ripple, DitheringShapes.simplex]).toContain(getCardArtSpec('one', 'step', inks).base.u_shape)
    expect(getCardArtSpec('one', 'placeholder', inks).base.u_shape).toBe(DitheringShapes.dots)
    expect(getCardArtSpec('one', 'gate', inks).base.u_shape).toBe(DitheringShapes.sphere)
  })

  it('varies shader settings across cards', () => {
    const specs = Array.from({ length: 20 }, (_, index) => getCardArtSpec(`card-${index}`, 'pr', inks))

    expect(new Set(specs.map((spec) => JSON.stringify(spec.base))).size).toBe(20)
  })
})
