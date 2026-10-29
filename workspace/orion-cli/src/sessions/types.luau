local types = require("@root/types")

type Item = types.Item
type Source = types.Source

-- A way to start an agent session from a card: which cards it fits and the
-- prompt it opens with. `branch` is the card's branch, when it has one.
export type Preset = {
	id: string,
	label: string,
	appliesTo: (Item) -> boolean,
	buildPrompt: (Item, branch: string?) -> string,
}

-- Where a session starts: a folder with the card's branch checked out, the
-- repository's main clone for the agent to make a worktree in, or no folder,
-- so the agent's app asks for one.
export type Place = "checkout" | "clone" | "none"

-- What starting a session from a card would do, or the problem in its way.
-- `agent` is the agent's name, such as "Claude Code", and `source` the agent
-- source that would start it. `attaches` says whether the canvas has that
-- source, which puts the new session on the card.
export type StartOptions = {
	presets: { Preset },
	agent: string,
	source: Source,
	attaches: boolean,
	repo: string?,
	branch: string?,
	place: Place,
	folder: string?,
	problem: string?,
}

-- A session start handed to the agent: the link opened, where it starts, and
-- the preset it used.
export type Start = {
	agent: string,
	place: Place,
	folder: string?,
	preset: Preset,
	url: string,
}

return nil
