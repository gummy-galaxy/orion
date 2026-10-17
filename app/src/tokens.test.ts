import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { THEMES } from './appearance'
import { TOKENS } from './tokens'

const read = (path: string) => readFileSync(new URL(path, import.meta.url), 'utf8')

/** Custom properties a stylesheet declares, ignoring comments and var() references. */
function declaredProperties(css: string): Set<string> {
  const withoutComments = css.replace(/\/\*[\s\S]*?\*\//g, '')

  return new Set([...withoutComments.matchAll(/(--[a-z0-9-]+)\s*:/gi)].map((match) => match[1]))
}

const collapse = (text: string) => text.replace(/\s+/g, ' ').replace(/\( /g, '(').replace(/ \)/g, ')').trim()

/** Each custom property's value, as a stylesheet first declares it. */
function declaredValues(css: string): Record<string, string> {
  const withoutComments = css.replace(/\/\*[\s\S]*?\*\//g, '')
  const values: Record<string, string> = {}

  for (const [, property, value] of withoutComments.matchAll(/(--[a-z0-9-]+)\s*:\s*([^;]+);/gi)) values[property] ??= collapse(value)

  return values
}

/** A light-dark() value's two halves, or the value twice when it doesn't depend on the scheme. */
function splitLightDark(value: string): [string, string] {
  const inner = value.match(/^light-dark\((.*)\)$/)?.[1]
  let depth = 0

  for (let i = 0; inner && i < inner.length; i++) {
    if (inner[i] === '(') depth++
    else if (inner[i] === ')') depth--
    else if (inner[i] === ',' && depth === 0) return [inner.slice(0, i).trim(), inner.slice(i + 1).trim()]
  }

  return [value, value]
}

/** The cells after the first in each table row that starts with a code span, keyed by that span. */
function documentedRows(markdown: string): Map<string, string[]> {
  const rows = new Map<string, string[]>()

  for (const line of markdown.split('\n')) {
    const cells = line
      .match(/^\|(.*)\|$/)?.[1]
      .split('|')
      .map((cell) => cell.trim().replace(/^`(.*)`$/, '$1'))

    if (cells && line.startsWith('| `')) rows.set(cells[0], cells.slice(1))
  }

  return rows
}

const sharedCss = read('./tokens.css')
const themeCss = Object.fromEntries(THEMES.map((theme) => [theme.id, read(`./themes/${theme.id}.css`)]))
const legacyNames = TOKENS.flatMap((token) => (token.legacy ? [token.legacy] : []))

it('gives every token a unique name and custom property', () => {
  const names = TOKENS.map((token) => token.name)
  const cssVars = TOKENS.map((token) => token.cssVar)

  expect(new Set(names).size).toBe(names.length)
  expect(new Set(cssVars).size).toBe(cssVars.length)
  expect(new Set(legacyNames).size).toBe(legacyNames.length)
  expect(legacyNames.filter((legacy) => cssVars.includes(legacy))).toEqual([])
})

describe.each(THEMES.map((theme) => theme.id))('theme %s', (themeId) => {
  it('defines every token, in the shared sheet or its own', () => {
    const defined = new Set([...declaredProperties(sharedCss), ...declaredProperties(themeCss[themeId])])
    const missing = TOKENS.map((token) => token.cssVar).filter((cssVar) => !defined.has(cssVar))

    expect(missing).toEqual([])
  })
})

it('aliases every legacy name to its token in tokens.css', () => {
  const missing = TOKENS.filter((token) => token.legacy).filter(
    (token) => !new RegExp(`${token.legacy}\\s*:\\s*var\\(${token.cssVar}\\)`).test(sharedCss),
  )

  expect(missing.map((token) => token.legacy)).toEqual([])
})

it('declares no custom property that the token list does not name', () => {
  const known = new Set([...TOKENS.map((token) => token.cssVar), ...legacyNames])
  const sheets = { 'tokens.css': sharedCss, ...Object.fromEntries(THEMES.map((theme) => [`${theme.id}.css`, themeCss[theme.id]])) }
  const unknown = Object.entries(sheets).flatMap(([file, css]) =>
    [...declaredProperties(css)].filter((property) => !known.has(property)).map((property) => `${file}: ${property}`),
  )

  expect(unknown).toEqual([])
})

describe('the tokens page in the docs', () => {
  const rows = documentedRows(read('../../docs/guide/tokens.md'))
  const defaults = { ...declaredValues(sharedCss), ...declaredValues(themeCss[THEMES[0].id]) }

  it('documents every token', () => {
    expect(TOKENS.map((token) => token.name).filter((name) => !rows.has(name))).toEqual([])
  })

  it('gives each token the default the stylesheets set', () => {
    const mismatched = TOKENS.flatMap((token) => {
      const bySchemes = token.group === 'color' || token.group === 'status'
      const documented = (rows.get(token.name) ?? []).slice(0, bySchemes ? 2 : 1).join(' | ')
      const expected = (bySchemes ? splitLightDark(defaults[token.cssVar]) : [defaults[token.cssVar]]).join(' | ')

      return documented === expected ? [] : [`${token.name}: ${documented} ≠ ${expected}`]
    })

    expect(mismatched).toEqual([])
  })

  it('lists every legacy name as an alias of its token', () => {
    const missing = TOKENS.filter((token) => token.legacy && rows.get(token.legacy)?.[0] !== token.name)

    expect(missing.map((token) => token.legacy)).toEqual([])
  })
})

it('matches the token contract that the CLI checks theme files against', () => {
  const contract = read('../../cli/src/themes/tokenContract.luau')
  const entries = [...contract.matchAll(/\["([^"]+)"\] = \{ group = "([^"]+)", cssVar = "([^"]+)"(?:, legacy = "([^"]+)")? \}/g)].map(
    ([, name, group, cssVar, legacy]) => ({ name, group, cssVar, legacy }),
  )

  expect(entries).toEqual(TOKENS.map(({ name, group, cssVar, legacy }) => ({ name, group, cssVar, legacy })))
})
