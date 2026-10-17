import { describe, expect, it } from 'vitest'
import { applyStyleChange, backgroundColor, groupLayers, headerText, isAssetId, readCanvasStyle } from './style'

describe('isAssetId', () => {
  it('accepts lowercase names with an image extension', () => {
    expect(isAssetId('image-logo.png')).toBe(true)
    expect(isAssetId('image-1760-42-3.webp')).toBe(true)
  })

  it('refuses paths, other extensions, colors, and missing values', () => {
    expect(isAssetId('../orion.json')).toBe(false)
    expect(isAssetId('image-logo.svg')).toBe(false)
    expect(isAssetId('#1d1b2e')).toBe(false)
    expect(isAssetId('card.background')).toBe(false)
    expect(isAssetId(undefined)).toBe(false)
  })
})

describe('backgroundColor', () => {
  it('passes hex colors through and turns a color token into its custom property', () => {
    expect(backgroundColor('#1d1b2e')).toBe('#1d1b2e')
    expect(backgroundColor('#abc')).toBe('#abc')
    expect(backgroundColor('card.background')).toBe('var(--card-background)')
  })

  it('returns nothing for images, unknown tokens, and malformed colors, so the group looks stock', () => {
    expect(backgroundColor('image-logo.png')).toBeUndefined()
    expect(backgroundColor('no.such-token')).toBeUndefined()
    expect(backgroundColor('#12345')).toBeUndefined()
    expect(backgroundColor('red')).toBeUndefined()
    expect(backgroundColor(undefined)).toBeUndefined()
  })
})

describe('readCanvasStyle', () => {
  it('keeps a cover asset and a background, and ignores anything else in the settings', () => {
    expect(readCanvasStyle({ sources: [], cover: 'image-logo.png', background: '#fff' })).toEqual({
      cover: 'image-logo.png',
      background: '#fff',
    })
    expect(readCanvasStyle({ cover: '../orion.json', background: 3 })).toEqual({})
    expect(readCanvasStyle(undefined)).toEqual({})
  })
})

describe('applyStyleChange', () => {
  it('keeps what the change leaves out, sets what it names, and clears what it nulls', () => {
    const style = { cover: 'image-logo.png', background: '#fff' }

    expect(applyStyleChange(style, { background: 'card.background' })).toEqual({
      cover: 'image-logo.png',
      background: 'card.background',
    })
    expect(applyStyleChange(style, { cover: null })).toEqual({ background: '#fff' })
    expect(applyStyleChange(style, {})).toEqual(style)
  })
})

describe('groupLayers', () => {
  it('paints a color, an image backdrop, and a cover on an open group', () => {
    expect(groupLayers({ cover: 'image-cover.png', background: 'image-back.jpg' }, false)).toEqual({
      backdrop: 'image-back.jpg',
      cover: 'image-cover.png',
    })
    expect(groupLayers({ background: 'canvas.background' }, false)).toEqual({ color: 'var(--canvas-background)' })
  })

  it('leaves the cover off a folded group, and paints nothing for a stock group', () => {
    expect(groupLayers({ cover: 'image-cover.png' }, true)).toEqual({})
    expect(groupLayers({}, false)).toEqual({})
  })
})

describe('headers', () => {
  it('reads a header from canvas settings and ignores blank or non-text ones', () => {
    expect(readCanvasStyle({ header: '# Orion' })).toEqual({ header: '# Orion' })
    expect(readCanvasStyle({ header: '   ' })).toEqual({})
    expect(readCanvasStyle({ header: 3 })).toEqual({})
  })

  it('sets and clears a header without touching the cover or background', () => {
    const styled = applyStyleChange({ cover: 'image-a.png', background: '#1d1b2e' }, { header: 'Hello' })

    expect(styled).toEqual({ cover: 'image-a.png', background: '#1d1b2e', header: 'Hello' })
    expect(applyStyleChange(styled, { header: null })).toEqual({ cover: 'image-a.png', background: '#1d1b2e' })
  })

  it('shows no header for whitespace', () => {
    expect(headerText('  \n ')).toBeUndefined()
    expect(headerText(undefined)).toBeUndefined()
    expect(headerText('Plan')).toBe('Plan')
  })
})
