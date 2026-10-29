local types = require("@root/types")

type Item = types.Item
type Source = types.Source

-- A way to start an agent session from a card: which cards it fits and the
-- prompt it opens with.
export type Preset = {
	id: string,
	label: string,
	appliesTo: (Item) -> boolean,
	buildPrompt: (Item, branch: string) -> string,
}

-- What starting a session from a card would do, or the problem in its way.
-- `agent` is the agent's name, such as "Claude Code", and `source` the agent
-- source that would start it.
export type StartOptions = {
	presets: { Preset },
	agent: string?,
	source: Source?,
	branch: string?,
	folder: string?,
	problem: string?,
}

-- A session start handed to the agent: the link opened, its folder, and the
-- preset it used.
export type Start = {
	agent: string,
	folder: string,
	preset: Preset,
	url: string,
}

return nil
