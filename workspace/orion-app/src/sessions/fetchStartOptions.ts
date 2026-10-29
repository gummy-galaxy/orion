import type { StartOptions } from './types'

/** The presets that fit a card and where a session would start, or null when the server can't say. */
export async function fetchStartOptions(workspace: string, cardId: string): Promise<StartOptions | null> {
  const query = new URLSearchParams({ canvas: workspace, id: cardId })
  const response = await fetch(`/api/sessions/start?${query}`).catch(() => null)

  if (!response?.ok) return null

  const body = (await response.json().catch(() => null)) as StartOptions | null

  return body && Array.isArray(body.presets) ? body : null
}
