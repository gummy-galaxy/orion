local cli = require("@batteries/cli")
local json = require("@std/json")

local addIdPositional = require("@root/cli/addIdPositional")
local context = require("@root/cli/context")
local getRequired = require("@root/cli/getRequired")
local resolveId = require("@root/query/resolveId")
local runTransaction = require("@root/store/runTransaction")
local unlinkItems = require("@root/graph/unlinkItems")
local writeResult = require("@root/cli/writeResult")

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
