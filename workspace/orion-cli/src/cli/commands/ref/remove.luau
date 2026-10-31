local cli = require("@batteries/cli")

local addIdPositional = require("@root/cli/arguments/addIdPositional")
local context = require("@root/cli/context")
local detachRequestedRef = require("@root/canvas/refs/detachRequestedRef")
local getRequired = require("@root/cli/arguments/getRequired")
local resolveId = require("@root/canvas/query/resolveId")
local runTransaction = require("@root/storage/transactions/runTransaction")
local types = require("@root/types")
local writeItem = require("@root/cli/output/writeItem")

type Context = context.Context
type Item = types.Item

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
			detached = detachRequestedRef(current, resolveId(current, idInput), input)
		end)

		writeItem(options, doc, detached, "Updated")
	end,
})
