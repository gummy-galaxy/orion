-- working: the agent is running a turn. waiting: it stopped on something only you can answer, such as a permission
-- prompt or an interrupted turn. done: it finished its turn.
export type SessionState = "working" | "waiting" | "done"
export type Turn = { role: "you" | "agent", text: string, at: string? }

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

-- A running Claude Code process, from its record in `sessions/`.
export type LiveSession = { pid: number, status: string, name: string? }

export type Session = {
	id: string,
	path: string,
	cwd: string,
	branch: string,
	title: string,
	state: SessionState,
	isLive: boolean,
	lastMessage: string?,
	updatedAt: number,
}

return {}
