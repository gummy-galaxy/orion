/**
 * A duration token's value in milliseconds, as the page resolves it, so a script that waits on an animation waits as
 * long as the theme makes it run. Falls back when there is no page, or the token isn't a plain time.
 */
export function readDurationMs(cssVar: string, fallback: number): number {
  if (typeof document === 'undefined') return fallback

  return parseDurationMs(getComputedStyle(document.documentElement).getPropertyValue(cssVar)) ?? fallback
}

/** A CSS time such as `420ms` or `0.8s` in milliseconds, or undefined for anything else. */
export function parseDurationMs(text: string): number | undefined {
  const match = text.trim().match(/^(\d+(?:\.\d+)?)(ms|s)$/)

  if (!match) return undefined

  return Number(match[1]) * (match[2] === 's' ? 1000 : 1)
}
