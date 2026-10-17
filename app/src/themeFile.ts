import { THEMES, type Scheme, type Theme } from './appearance'
import { TOKENS, type Token } from './tokens'

/**
 * Shareable theme files, read from the themes folder in the data folder through `orion server start`. A file names
 * its theme and gives token values by scheme; see docs/guide/themes.md. A value reaches the page only after it passes
 * checkValue, so a file can set colors and sizes but cannot load a URL or add rules.
 */
const API = '/api/themes'
/** Long enough for a local server, short enough not to hold up the first render when there's none. */
const LOAD_TIMEOUT_MS = 1500
const SCHEMES: readonly Scheme[] = ['light', 'dark']
const MAX_LABEL_LENGTH = 40
const MAX_VALUE_LENGTH = 200
/** Radii may be a percentage, so they are checked against a larger number than sizes and spacing. */
const MAX_RADIUS = 1000

/** Functions a color may call. url(), image-set(), expression(), and the rest are not on the list. */
const COLOR_FUNCTIONS = ['rgb', 'rgba', 'hsl', 'hsla', 'hwb', 'oklab', 'oklch', 'color-mix', 'var']
const COLOR_TEXT = /^[a-z0-9 #%.,()+\-/]+$/i
const FONT_TEXT = /^[a-z0-9 ,'"_-]+$/i
const SIZE = /^(0|\d+(\.\d+)?(px|rem|em))$/
const RADIUS = /^(0|\d+(\.\d+)?(px|rem|em|%))( (0|\d+(\.\d+)?(px|rem|em|%))){0,3}$/
const WEIGHT = /^\d+$/
const DURATION = /^\d+(\.\d+)?(ms|s)$/
/** Longer than any transition should run, so a typo can't freeze the interface for minutes. */
const MAX_DURATION_MS = 10_000
const EASING_KEYWORDS = ['ease', 'ease-in', 'ease-out', 'ease-in-out', 'linear']
const NUMBER = '-?\\d+(\\.\\d+)?'
const CUBIC_BEZIER = new RegExp(`^cubic-bezier\\(\\s*${NUMBER}(\\s*,\\s*${NUMBER}){3}\\s*\\)$`)

type Problem = string | null

const isRecord = (value: unknown): value is Record<string, unknown> => typeof value === 'object' && value !== null && !Array.isArray(value)

const tokensByName = new Map(TOKENS.map((token) => [token.name, token]))
const cssVars = new Set(TOKENS.flatMap((token) => [token.cssVar, ...(token.legacy ? [token.legacy] : [])]))

const fileLabel = (file: string) => file.replace(/\.json$/, '')

/** A theme that could not be used. It is listed in the picker with its reason. */
export function brokenTheme(file: string, error: string): Theme {
  return { id: `custom:${file}`, label: fileLabel(file), schemes: [], error }
}

/** Checks one value against its token's type. Returns the problem, or null when the value is plain CSS for that type. */
export function checkValue(token: Token, value: string): Problem {
  const text = value.trim()

  if (!text) return 'is empty'

  if (text.length > MAX_VALUE_LENGTH) return 'is too long'

  switch (token.group) {
    case 'color':
    case 'status':
      return checkColor(text)
    case 'font':
      return checkFont(text)
    case 'weight':
      return WEIGHT.test(text) && Number(text) >= 100 && Number(text) <= 1000 ? null : 'must be a weight from 100 to 1000'
    case 'size':
    case 'space':
    case 'border':
      return SIZE.test(text) && Number.parseFloat(text) <= MAX_VALUE_LENGTH ? null : 'must be a length in px, rem, or em'
    case 'radius':
      return RADIUS.test(text) && text.split(' ').every((part) => Number.parseFloat(part) <= MAX_RADIUS)
        ? null
        : 'must be one to four lengths in px, rem, em, or %'
    case 'shadow':
      return checkShadow(text)
    case 'duration':
      return checkDuration(text)
    case 'easing':
      return EASING_KEYWORDS.includes(text) || CUBIC_BEZIER.test(text) ? null : 'must be an easing keyword or cubic-bezier()'
  }
}

/**
 * A color is hex, a named color, or one of the color functions over plain numbers and words. Words are allowed
 * because they cannot carry anything; the browser drops a name it does not know (see browserRejects).
 */
function checkColor(text: string): Problem {
  if (!balanced(text)) return 'has unbalanced parentheses'

  const unknown = [...text.matchAll(/([a-z-]+)\(/gi)].map((match) => match[1].toLowerCase()).find((name) => !COLOR_FUNCTIONS.includes(name))

  if (unknown) return `uses ${unknown}(), which a color cannot`

  const references = [...text.matchAll(/var\(\s*(--[a-z0-9-]+)\s*\)/gi)].map((match) => match[1].toLowerCase())
  const allVars = text.match(/var\(/gi) ?? []

  if (references.some((name) => !cssVars.has(name)) || allVars.length !== references.length) return 'refers to a variable this theme cannot name'

  if (!COLOR_TEXT.test(text)) return 'has characters that are not part of a color'

  return null
}

/** A shadow is lengths, the word inset, and colors, so it follows the color rules and lets the browser check the shape. */
function checkShadow(text: string): Problem {
  if (text === 'none') return null

  return checkColor(text)?.replace('part of a color', 'part of a shadow') ?? null
}

function checkDuration(text: string): Problem {
  if (!DURATION.test(text)) return 'must be a time in ms or s'

  const ms = Number.parseFloat(text) * (text.endsWith('ms') ? 1 : 1000)

  return ms <= MAX_DURATION_MS ? null : 'must be 10s or less'
}

function checkFont(text: string): Problem {
  if (!FONT_TEXT.test(text)) return 'has characters that are not part of a font name'

  if ((text.match(/'/g) ?? []).length % 2 !== 0 || (text.match(/"/g) ?? []).length % 2 !== 0) return 'has unbalanced quotes'

  return null
}

function balanced(text: string): boolean {
  let depth = 0

  for (const character of text) {
    if (character === '(') depth += 1

    if (character === ')') depth -= 1

    if (depth < 0) return false
  }

  return depth === 0
}

const PROPERTY_FOR_GROUP: Record<Token['group'], string> = {
  color: 'color',
  status: 'color',
  font: 'font-family',
  weight: 'font-weight',
  size: 'font-size',
  space: 'padding',
  border: 'border-width',
  radius: 'border-radius',
  shadow: 'box-shadow',
  duration: 'transition-duration',
  easing: 'transition-timing-function',
}

/** Where the browser exists, it has the last word on a value its parser would drop. Elsewhere the checks above stand alone. */
function browserRejects(token: Token, value: string): boolean {
  if (typeof CSS === 'undefined' || typeof CSS.supports !== 'function') return false

  return !CSS.supports(PROPERTY_FOR_GROUP[token.group], value)
}

/**
 * Reads one theme file. A file that cannot be used comes back as a broken theme with its reason. Tokens the
 * file leaves out fall back to the default theme, and names it does not know are noted and skipped.
 */
export function parseThemeFile(file: string, text: string): Theme {
  let data: unknown

  try {
    data = JSON.parse(text)
  } catch {
    return brokenTheme(file, 'is not valid JSON')
  }

  if (!isRecord(data)) return brokenTheme(file, 'must be a JSON object')

  const label = typeof data.name === 'string' && data.name.trim() ? data.name.trim().slice(0, MAX_LABEL_LENGTH) : fileLabel(file)
  const notes: string[] = []
  const values: Partial<Record<Scheme, Record<string, string>>> = {}

  for (const scheme of SCHEMES) {
    const source = data[scheme]

    if (source === undefined) continue

    if (!isRecord(source)) return brokenTheme(file, `"${scheme}" must be an object of token values`)

    const variant: Record<string, string> = {}

    for (const [name, value] of Object.entries(source)) {
      const token = tokensByName.get(name)

      if (!token) {
        notes.push(`Ignored unknown token ${name} in ${scheme}`)
        continue
      }

      if (typeof value !== 'string') return brokenTheme(file, `${scheme} ${name} must be a string`)

      const problem = checkValue(token, value)

      if (problem) return brokenTheme(file, `${scheme} ${name} ${problem}`)

      if (browserRejects(token, value.trim())) return brokenTheme(file, `${scheme} ${name} is not a value the browser accepts`)

      variant[name] = value.trim()
    }

    values[scheme] = variant
  }

  const schemes = SCHEMES.filter((scheme) => values[scheme])

  if (schemes.length === 0) return brokenTheme(file, 'needs a "light" or "dark" object of token values')

  const author = typeof data.author === 'string' && data.author.trim() ? data.author.trim().slice(0, MAX_LABEL_LENGTH) : undefined

  return { id: `custom:${file}`, label, schemes, values, notes, author }
}

/** The picker's list as the last load left it, so the first render can use it before a reload finishes. */
let loaded: Theme[] = [...THEMES]

/** The built-in themes, then the valid theme files, then the broken ones with their reasons. */
export function themeList(files: readonly Theme[]): Theme[] {
  return [...THEMES, ...files.filter((theme) => theme.error === undefined), ...files.filter((theme) => theme.error !== undefined)]
}

/** Reads the theme files from the body of GET /api/themes. Entries that are not shaped like a file are skipped. */
function readThemeBody(body: unknown): Theme[] {
  const entries = isRecord(body) && Array.isArray(body.themes) ? body.themes : []

  return entries.flatMap((entry): Theme[] => {
    if (!isRecord(entry) || typeof entry.file !== 'string') return []

    if (typeof entry.text !== 'string') return [brokenTheme(entry.file, typeof entry.error === 'string' ? entry.error : 'could not be read')]

    return [parseThemeFile(entry.file, entry.text)]
  })
}

export function cachedThemes(): Theme[] {
  return loaded
}

/**
 * Fetches the theme files in the data folder and returns the picker's list. With no server, as in Storybook, or
 * when the request fails, the list is the built-in themes alone.
 */
export async function loadThemes(): Promise<Theme[]> {
  let files: Theme[] = []

  try {
    const response = await fetch(API, { signal: AbortSignal.timeout(LOAD_TIMEOUT_MS) })

    if (response.ok) files = readThemeBody((await response.json()) as unknown)
  } catch {
    // Nothing to read: the built-in themes still show.
  }

  loaded = themeList(files)

  return loaded
}
