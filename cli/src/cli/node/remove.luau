local cli = require("@batteries/cli")

local addBatchOptions = require("@root/cli/addBatchOptions")
local context = require("@root/cli/context")
local graph = require("@root/graph")
local isBatchEdit = require("@root/cli/isBatchEdit")
local runBatchEdit = require("@root/cli/runBatchEdit")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Remove items; optionally reconnect a card's links",
	define = function(parser: cli.Parser)
		addBatchOptions(parser, "Item ids")
		parser:add("reconnect", "flag", { help = "Reconnect at most one incoming and outgoing link per item" })
	end,

	run = function(parser: cli.Parser, options: Context)
		if isBatchEdit(parser) then
			runBatchEdit(parser, options, "remove")
			return
		end

		local id = parser:variadics()[1]

		store.transaction(options.dir, function(doc)
			graph.remove(doc, id)
		end)

		options.write(`Removed {id}`)
	end,
})
