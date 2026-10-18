import { useState } from 'react'
import type { SourceRef } from '../model'
import { getCardSession } from '../sessions/getCardSession'
import { useSessionTurns } from '../sessions/useSessionTurns'
import { CompanionChat } from './CompanionChat'

/** Opens the companion's chat when the one selected card has an agent session. Closing it lasts until the selection moves. */
export function SelectedSessionChat({ workspace, cardId, refs }: { workspace: string; cardId: string | undefined; refs: SourceRef[] | undefined }) {
  const session = cardId ? getCardSession(refs) : undefined
  const turns = useSessionTurns(workspace, session?.key)
  const [closedFor, setClosedFor] = useState<string | null>(null)

  if (!session || closedFor === cardId) return null

  return <CompanionChat session={session} turns={turns} onClose={() => setClosedFor(cardId ?? null)} />
}
