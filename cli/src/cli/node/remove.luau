local cli = require("@batteries/cli")

local addBatchOptions = require("@root/cli/addBatchOptions")
local context = require("@root/cli/context")
local graph = require("@root/graph")
local isBatchEdit = require("@root/cli/isBatchEdit")
local resolveId = require("@root/query/resolveId")
local runBatchEdit = require("@root/cli/runBatchEdit")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Remove items. Removing a note reconnects the links that ran through it",
	define = function(parser: cli.Parser)
		addBatchOptions(parser, "Item ids or selectors")
		parser:add("reconnect", "flag", {
			help = "Also reconnect cards with at most one incoming and one outgoing link; every selected card must qualify",
		})
	end,

	run = function(parser: cli.Parser, options: Context)
		if isBatchEdit(parser) then
			runBatchEdit(parser, options, "remove")
			return
		end

		local id: string

		store.transaction(options.dir, function(doc)
			id = resolveId(doc, parser:variadics()[1])
			graph.remove(doc, id)
		end)

		options.write(`Removed {id}`)
	end,
})
