local cli = require("@batteries/cli")

local addIdPositional = require("@root/cli/addIdPositional")
local context = require("@root/cli/context")
local detachRef = require("@root/graph/detachRef")
local getCurrentKey = require("@root/github/getCurrentKey")
local getItem = require("@root/graph/getItem")
local getRefs = require("@root/refs/getRefs")
local getRequired = require("@root/cli/getRequired")
local isGroup = require("@root/graph/isGroup")
local resolveId = require("@root/query/resolveId")
local resolveRef = require("@root/adapters/resolveRef")
local runTransaction = require("@root/store/runTransaction")
local types = require("@root/types")
local writeItem = require("@root/cli/writeItem")

type Context = context.Context
type Doc = types.Doc
type Item = types.Item

-- Takes a ref off an item by the key orion node show lists. A URL or source:key that isn't a key on the item resolves
-- the way --ref does, and then has to match that ref's kind too.
local function detachInput(doc: Doc, id: string, input: string): Item
	local item = getItem(doc, id)
	assert(not isGroup(item), "groups don't take refs")

	local current = getCurrentKey(doc, input)

	for _, ref in getRefs(item) do
		if ref.key:lower() == input:lower() or ref.key:lower() == current:lower() then
			return detachRef(doc, id, ref.key)
		end
	end

	assert(input:find(":"), `"{id}" has no ref {input}`)
	local resolved = resolveRef(input, doc.settings.sources)
	return detachRef(doc, id, getCurrentKey(doc, resolved.ref.key), resolved.ref.kind)
end

return table.freeze({
	help = "Take a ref off an item",
	mcp = {},
	define = function(parser: cli.Parser)
		addIdPositional(parser, "id")
		parser:add(
			"ref",
			"positional",
			{ help = "The ref's key as orion node show lists it, such as owner/name#12, or a URL or source:key" }
		)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local idInput = getRequired(parser, "id")
		local input = getRequired(parser, "ref")

		local detached: Item
		local doc = runTransaction(options.dir, function(current)
			detached = detachInput(current, resolveId(current, idInput), input)
		end)

		writeItem(options, doc, detached, "Updated")
	end,
})
