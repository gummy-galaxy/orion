import { describe, expect, it } from 'vitest'
import type { PosterInput } from './posterSpec'
import { getPosterSpec } from './posterSpec'

const base: PosterInput = { artSeed: 'poster-42', kind: 'step', status: 'active', upstream: 3, leverage: 2 }

describe('getPosterSpec', () => {
  it('is deterministic and varies with the seed', () => {
    expect(getPosterSpec(base)).toEqual(getPosterSpec(base))
    expect(getPosterSpec(base)).not.toEqual(getPosterSpec({ ...base, artSeed: 'poster-43' }))
  })

  it('gives six layouts distinct compositions', () => {
    const layouts = Array.from({ length: 6 }, (_, template) => getPosterSpec(base, template))

    expect(new Set(layouts.map((layout) => JSON.stringify(layout.shapes))).size).toBe(6)
  })

  it('encodes upstream in capped strata and leverage in wedges', () => {
    expect(getPosterSpec({ ...base, upstream: 0 }).shapes).not.toEqual(getPosterSpec(base).shapes)
    expect(getPosterSpec({ ...base, leverage: 0 }).shapes).not.toEqual(getPosterSpec(base).shapes)
    expect(getPosterSpec({ ...base, upstream: 20 }).excessUpstream).toBe(8)
    expect(getPosterSpec({ ...base, upstream: 20 }).shapes).toEqual(getPosterSpec({ ...base, upstream: 12 }).shapes)
    expect(getPosterSpec({ ...base, leverage: 20 }).shapes).toEqual(getPosterSpec({ ...base, leverage: 6 }).shapes)
  })

  it('gives each kind its geometric family even without color', () => {
    const kinds = ['step', 'pr', 'placeholder', 'gate', 'note'] as const
    const specimens = kinds.map((kind) => getPosterSpec({ ...base, kind }, 0).shapes)

    expect(specimens[0].some((shape) => shape.tag === 'rect' && Number(shape.attrs.width) > 100)).toBe(true)
    expect(specimens[1].some((shape) => shape.tag === 'polygon' && String(shape.attrs.points).split(' ').length === 5)).toBe(true)
    expect(specimens[2].some((shape) => shape.tag === 'circle' && shape.stroke)).toBe(true)
    expect(specimens[3].some((shape) => shape.tag === 'path' && String(shape.attrs.d).includes('A'))).toBe(true)
    expect(specimens[4].some((shape) => shape.tag === 'path' && String(shape.attrs.d).includes('C'))).toBe(true)
  })

  it('changes dominant marks by status', () => {
    expect(
      new Set(
        (['ready', 'active', 'review', 'blocked', 'deferred', 'done'] as const).map((status) =>
          JSON.stringify(getPosterSpec({ ...base, status }).shapes),
        ),
      ).size,
    ).toBe(6)
  })
})
