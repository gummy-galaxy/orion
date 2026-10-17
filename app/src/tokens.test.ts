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

it('documents every token in tokens.md', () => {
  const doc = read('./tokens.md')
  const undocumented = TOKENS.filter((token) => !doc.includes(`\`${token.name}\``)).map((token) => token.name)

  expect(undocumented).toEqual([])
})

it('matches the token contract that the CLI checks theme files against', () => {
  const contract = read('../../cli/src/themes/tokenContract.luau')
  const entries = [...contract.matchAll(/\["([^"]+)"\] = \{ group = "([^"]+)", cssVar = "([^"]+)"(?:, legacy = "([^"]+)")? \}/g)].map(
    ([, name, group, cssVar, legacy]) => ({ name, group, cssVar, legacy }),
  )

  expect(entries).toEqual(TOKENS.map(({ name, group, cssVar, legacy }) => ({ name, group, cssVar, legacy })))
})
