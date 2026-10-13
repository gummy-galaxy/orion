-- How Orion describes itself to agents and people. Connected MCP clients receive `paragraphs` as the
-- initialize instructions. `orion help` prints `help` under the summary: the same vocabulary, written
-- for a terminal reader, with no MCP tool names. The spec checks that every MCP tool named in
-- `paragraphs` exists, so that text follows the tool catalog as it grows.
return table.freeze({
	help = table.freeze({
		"Orion is the user's local graph of work: items, notes, and groups linked by dependencies, shown on a canvas. A canvas is a workspace. Pass --workspace to pick one, or the active workspace is used.",
		"A link runs from the work that has to happen first to the work that waits on it. Setting a note replaces its whole text.",
		"Record the branch a card's work is on with `orion set <id> --ref branch:<owner>/<repo>@<branch>`. Orion attaches a pull request opened from that branch to the card on the next ingest.",
	}),
	paragraphs = table.freeze({
		'Orion is the user\'s local graph of work: items, notes, and groups linked by dependencies, shown on a canvas. In these tools a canvas is a workspace. People may say board or dashboard, often by name, as in "my focus", so call orion_workspaces first to map that name to one.',
		"Call orion_inspect before editing. A link runs from the work that has to happen first to the work that waits on it. Writing a note replaces its whole text, so read an item before changing its note. Write notes as a plain-language summary, with Markdown for structure and code formatting for code, paths, and identifiers.",
		'When you start work on a card, record its branch with orion_update_item and ref "branch:<owner>/<repo>@<branch>". Orion attaches a pull request you open from that branch to the card the next time it ingests (orion_ingest). If no card exists for the work yet, add one with orion_add_item first.',
		"Prefer the orion_ tools when they are connected. The CLI runs the same implementation, for anything they don't cover.",
	}),
})
