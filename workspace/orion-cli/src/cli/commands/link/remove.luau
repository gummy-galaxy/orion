local cli = require("@batteries/cli")
local json = require("@std/json")

local addIdPositional = require("@root/cli/arguments/addIdPositional")
local context = require("@root/cli/context")
local getRequired = require("@root/cli/arguments/getRequired")
local resolveId = require("@root/canvas/query/resolveId")
local runTransaction = require("@root/storage/transactions/runTransaction")
local unlinkItems = require("@root/canvas/links/unlinkItems")
local writeResult = require("@root/cli/output/writeResult")

type Context = context.Context

return table.freeze({
	help = "Remove the link between two items",
	mcp = {},
	define = function(parser: cli.Parser)
		addIdPositional(parser, "from")
		addIdPositional(parser, "to")
	end,

	run = function(parser: cli.Parser, options: Context)
		local from, to = getRequired(parser, "from"), getRequired(parser, "to")

		local doc = runTransaction(options.dir, function(current)
			from, to = resolveId(current, from), resolveId(current, to)
			unlinkItems(current, from, to)
		end)

		writeResult(
			options,
			json.object({ revision = doc.revision, from = from, to = to }),
			`Removed the link from {from} to {to}`
		)
	end,
})
