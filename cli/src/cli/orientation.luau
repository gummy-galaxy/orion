-- How Orion describes itself to agents. Connected MCP clients receive these paragraphs as the
-- initialize instructions, and `orion help` prints them under the summary. The spec checks that
-- every MCP tool named here exists, so this text follows the tool catalog as it grows.
return table.freeze({
	paragraphs = table.freeze({
		'Orion is the user\'s local graph of work: items, notes, and groups linked by dependencies, shown on a canvas. In these tools a canvas is a workspace. People may say board or dashboard, often by name, as in "my focus", so call orion_workspaces first to map that name to one.',
		"Call orion_inspect before editing. A link runs from the work that has to happen first to the work that waits on it. Writing a note replaces its whole text, so read an item before changing its note.",
		'When you start work on a card, record its branch with orion_update_item and ref "branch:<owner>/<repo>@<branch>". Orion attaches a pull request you open from that branch to the card the next time it ingests (orion_ingest). If no card exists for the work yet, add one with orion_add_item first.',
		"Prefer the orion_ tools when they are connected. The CLI runs the same implementation, for anything they don't cover.",
	}),
})
