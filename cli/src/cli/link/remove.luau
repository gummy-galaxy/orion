local cli = require("@batteries/cli")

local addIdPositional = require("@root/cli/addIdPositional")
local context = require("@root/cli/context")
local getRequired = require("@root/cli/getRequired")
local graph = require("@root/graph")
local resolveId = require("@root/query/resolveId")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Remove the link between two items",
	define = function(parser: cli.Parser)
		addIdPositional(parser, "from")
		addIdPositional(parser, "to")
	end,

	run = function(parser: cli.Parser, options: Context)
		local from, to = getRequired(parser, "from"), getRequired(parser, "to")

		store.transaction(options.dir, function(doc)
			from, to = resolveId(doc, from), resolveId(doc, to)
			graph.unlink(doc, from, to)
		end)

		options.write(`Removed the link from {from} to {to}`)
	end,
})
