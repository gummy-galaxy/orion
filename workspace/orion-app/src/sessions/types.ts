/** A way to start an agent session from a card, as `orion session presets` lists it. */
export type SessionPreset = { id: string; label: string }

/**
 * Where a session starts: a folder with the card's branch checked out, the repository's main clone for the agent
 * to make a worktree in, or no folder, so the agent's app asks for one.
 */
export type StartPlace = 'checkout' | 'clone' | 'none'

/** What starting a session from a card would do, as the server works it out. */
export type StartOptions = {
  presets: SessionPreset[]
  /** The agent that would run, such as "Claude Code". */
  agent: string
  /** Whether the canvas has the agent's source, which puts the new session on the card. */
  attaches: boolean
  repo: string | null
  branch: string | null
  place: StartPlace
  folder: string | null
  /** Set only when the item can't start a session at all. */
  problem: string | null
}
