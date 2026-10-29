/** A way to start an agent session from a card, as `orion session presets` lists it. */
export type SessionPreset = { id: string; label: string }

/** What starting a session from a card would do, or what's in the way, as the server works it out. */
export type StartOptions = {
  presets: SessionPreset[]
  /** The agent that would run, such as "Claude Code". */
  agent: string | null
  /** The folder where the card's branch is checked out. */
  folder: string | null
  problem: string | null
}
