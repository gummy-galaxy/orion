local adapterTypes = require("@root/adapters/types")

type SessionState = adapterTypes.SessionState
type Turn = adapterTypes.Turn

-- What a transcript says about its session, read from the end of the file.
export type Transcript = {
	branch: string?,
	cwd: string?,
	title: string?,
	lastMessage: string?,
	lastAt: string?,
	state: SessionState,
	turns: { Turn },
}

-- A running Claude Code process, from its record in `sessions/`: busy while
-- it runs a turn, and idle or waiting once it's your move.
export type LiveSession = { pid: number, status: string, name: string? }

return nil
