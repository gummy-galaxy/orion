import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { TOKENS } from './tokens'
import { checkValue, parseThemeFile } from './themeFile'

const token = (name: string) => TOKENS.find((item) => item.name === name)!

const file = (body: unknown) => JSON.stringify(body)

describe('parseThemeFile', () => {
  it('reads both schemes and the name and author', () => {
    const theme = parseThemeFile(
      'dusk.json',
      file({ name: 'Dusk', author: 'Orion', light: { 'canvas.background': '#fff' }, dark: { 'canvas.background': '#000' } }),
    )

    expect(theme).toEqual({
      id: 'custom:dusk.json',
      label: 'Dusk',
      author: 'Orion',
      schemes: ['light', 'dark'],
      values: { light: { 'canvas.background': '#fff' }, dark: { 'canvas.background': '#000' } },
      notes: [],
    })
  })

  it('takes the label from the file name when the file has no name, and caps long names', () => {
    expect(parseThemeFile('night.json', file({ dark: { 'canvas.background': '#000' } })).label).toBe('night')
    expect(parseThemeFile('x.json', file({ name: '   ', dark: {} })).label).toBe('x')
    expect(parseThemeFile('x.json', file({ name: 'a'.repeat(80), dark: {} })).label).toHaveLength(40)
  })

  it('makes a theme with one scheme when the file has only that variant', () => {
    const theme = parseThemeFile('dark.json', file({ dark: { 'canvas.background': '#000' } }))

    expect(theme.schemes).toEqual(['dark'])
    expect(theme.values?.light).toBeUndefined()
  })

  it('ignores tokens it does not name, and says so', () => {
    const theme = parseThemeFile('x.json', file({ light: { 'canvas.background': '#fff', 'canvas.glow': '#f00' } }))

    expect(theme.error).toBeUndefined()
    expect(theme.values?.light).toEqual({ 'canvas.background': '#fff' })
    expect(theme.notes).toEqual(['Ignored unknown token canvas.glow in light'])
  })

  it('ignores prototype keys in a variant', () => {
    const theme = parseThemeFile('x.json', file({ dark: { __proto__: '#fff', constructor: '#000' } }))

    expect(theme.error).toBeUndefined()
    expect(Object.keys(theme.values?.dark ?? {})).toEqual([])
  })

  it.each([
    ['is not JSON', '{nope'],
    ['is not an object', '[]'],
    ['has no variant', '{"name":"Empty"}'],
    ['has a variant that is not an object', '{"dark":"#000"}'],
  ])('reports a file that %s as a broken theme', (_, text) => {
    const theme = parseThemeFile('bad.json', text)

    expect(theme.id).toBe('custom:bad.json')
    expect(theme.schemes).toEqual([])
    expect(theme.error).toBeTypeOf('string')
  })

  it('reports a value that is not a string', () => {
    expect(parseThemeFile('x.json', file({ dark: { 'canvas.background': 3 } })).error).toBe('dark canvas.background must be a string')
  })

  it('reports the first value that is not plain CSS for its token', () => {
    const theme = parseThemeFile('x.json', file({ light: { 'canvas.background': 'url(https://example.com/a.png)' } }))

    expect(theme.error).toBe('light canvas.background uses url(), which a color cannot')
    expect(theme.schemes).toEqual([])
  })
})

describe('checkValue', () => {
  it.each([
    ['canvas.background', '#fff'],
    ['canvas.background', '#1c1726cc'],
    ['canvas.background', 'rebeccapurple'],
    ['canvas.background', 'transparent'],
    ['canvas.background', 'rgb(10 20 30 / 50%)'],
    ['accent.subtle', 'color-mix(in srgb, #b4481f 20%, #fff)'],
    ['edge.held', 'var(--edge-hot)'],
    ['canvas.background', 'var(--surface-background)'],
    ['canvas.background', 'var(--surface)'],
    ['font.ui', "'Schibsted Grotesk', system-ui, sans-serif"],
    ['weight.bold', '700'],
    ['text.size.body', '13px'],
    ['text.size.body', '0.8rem'],
    ['space.4', '8px'],
    ['radius.note-corner', '0 7px 0 3px'],
    ['radius.round', '50%'],
  ])('accepts %s: %s', (name, value) => {
    expect(checkValue(token(name), value)).toBeNull()
  })

  it.each([
    ['canvas.background', 'url(https://example.com/a.png)'],
    ['canvas.background', 'image-set("a.png" 1x)'],
    ['canvas.background', 'expression(alert(1))'],
    ['canvas.background', 'light-dark(#fff, #000)'],
    ['canvas.background', '#fff; } body { background: red'],
    ['canvas.background', '#fff) url(https://example.com)'],
    ['canvas.background', '#fff)('],
    ['canvas.background', 'var(--not-a-token)'],
    ['canvas.background', 'var(--surface-background, red)'],
    ['canvas.background', '@import "x.css"'],
    ['canvas.background', 'red\\7b'],
    ['canvas.background', ''],
    ['font.ui', 'Arial; }'],
    ['font.ui', 'url(font.woff2)'],
    ['font.ui', "'Schibsted Grotesk"],
    ['weight.bold', 'bold'],
    ['weight.bold', '1200'],
    ['text.size.body', '13'],
    ['text.size.body', '900px'],
    ['space.4', '-4px'],
    ['radius.card', '1px 2px 3px 4px 5px'],
    ['radius.card', 'calc(1px + 2px)'],
  ])('rejects %s: %s', (name, value) => {
    expect(checkValue(token(name), value)).toEqual(expect.any(String))
  })
})

describe('the example theme', () => {
  it('ships a valid theme that names only real tokens', () => {
    const text = readFileSync(new URL('../../examples/themes/dusk.json', import.meta.url), 'utf8')
    const theme = parseThemeFile('dusk.json', text)

    expect(theme.error).toBeUndefined()
    expect(theme.notes).toEqual([])
    expect(theme.schemes).toEqual(['light', 'dark'])
  })
})
