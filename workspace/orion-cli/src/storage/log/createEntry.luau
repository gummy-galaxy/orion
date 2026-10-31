local findItem = require("@root/canvas/items/findItem")
local isGroup = require("@root/canvas/groups/isGroup")
local types = require("@root/types")

type Doc = types.Doc
type LogAuthor = types.LogAuthor
type LogEntry = types.LogEntry
type LogTarget = types.LogTarget

export type Input = {
	text: string,
	author: LogAuthor,
	cards: { string },
	time: string,
}

-- Builds the next entry. Each card it names must be on the canvas, and each
-- card is attached once.
local function createEntry(entries: { LogEntry }, doc: Doc, input: Input): LogEntry
	assert(input.text:match("%S"), "log text must not be empty")

	local targets: { LogTarget } = {}
	local attached: { [string]: boolean } = {}

	for _, id in input.cards do
		local item = findItem(doc, id)
		assert(item, `no item with id "{id}"`)
		assert(not isGroup(item), `"{id}" is a group; log against a card`)

		if not attached[id] then
			attached[id] = true
			local target: LogTarget = { kind = "card", id = id }
			table.insert(targets, target)
		end
	end

	return {
		-- Entries are never removed, so counting them gives each one a fresh
		-- id.
		id = `log-{#entries + 1}`,
		text = input.text,
		time = input.time,
		author = input.author,
		targets = targets,
	}
end

return createEntry
