/** Opens an agent session on the card's work with the preset, and fails with the server's reason. */
export async function startSession(workspace: string, cardId: string, preset: string): Promise<void> {
  const response = await fetch('/api/sessions/start', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ canvas: workspace, id: cardId, preset }),
  })

  if (response.ok) return

  const body = (await response.json().catch(() => ({}))) as { error?: string }

  throw new Error(body.error || 'Could not start a session for this card')
}
