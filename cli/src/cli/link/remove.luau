local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local getRequired = require("@root/cli/getRequired")
local graph = require("@root/graph")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Remove the link between two items",
	define = function(parser: cli.Parser)
		parser:add("from", "positional", { help = "Link source" })
		parser:add("to", "positional", { help = "Link target" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local from, to = getRequired(parser, "from"), getRequired(parser, "to")

		store.transaction(options.dir, function(doc)
			graph.unlink(doc, from, to)
		end)

		options.write(`Removed the link from {from} to {to}`)
	end,
})
