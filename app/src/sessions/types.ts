/** working: the agent is running a turn. waiting: it stopped on something only you can answer. done: it finished its turn. */
export type SessionState = 'working' | 'waiting' | 'done'

/** An agent session a card carries, from its `session` ref. The CLI's agent adapter fills in these facts. */
export type CardSession = {
  key: string
  title: string
  state: SessionState
  lastMessage?: string
  updatedAt?: string
  /** Whether the agent's process is still running, so a resume could collide with it. */
  isLive: boolean
}

export type SessionTurn = { role: 'you' | 'agent'; text: string; at?: string }

export const SESSION_STATE_LABEL: Record<SessionState, string> = {
  working: 'Working',
  waiting: 'Waiting on you',
  done: 'Finished its turn',
}
