import type { SessionTurn } from './types'

const API = '/api/sessions/turns'

function isTurn(value: unknown): value is SessionTurn {
  if (!value || typeof value !== 'object') return false

  const turn = value as Record<string, unknown>

  return (turn.role === 'you' || turn.role === 'agent') && typeof turn.text === 'string'
}

/** A session's last few turns, read from its agent's transcript through `orion serve`. Null when it can't be read. */
export async function fetchSessionTurns(workspace: string, key: string): Promise<SessionTurn[] | null> {
  try {
    const response = await fetch(`${API}?canvas=${encodeURIComponent(workspace)}&key=${encodeURIComponent(key)}`)

    if (!response.ok || !response.headers.get('content-type')?.includes('json')) return null

    const body = (await response.json()) as { turns?: unknown }

    return Array.isArray(body.turns) ? body.turns.filter(isTurn) : null
  } catch {
    return null
  }
}
