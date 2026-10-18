local cli = require("@batteries/cli")

local addBatchOptions = require("@root/cli/addBatchOptions")
local context = require("@root/cli/context")
local isBatchEdit = require("@root/cli/isBatchEdit")
local removeItem = require("@root/graph/removeItem")
local resolveId = require("@root/query/resolveId")
local runBatchEdit = require("@root/cli/runBatchEdit")
local runTransaction = require("@root/store/runTransaction")

type Context = context.Context

return table.freeze({
	help = "Remove items; optionally reconnect a card's links",
	define = function(parser: cli.Parser)
		addBatchOptions(parser, "Item ids or selectors")
		parser:add("reconnect", "flag", { help = "Reconnect at most one incoming and outgoing link per item" })
	end,

	run = function(parser: cli.Parser, options: Context)
		if isBatchEdit(parser) then
			runBatchEdit(parser, options, "remove")
			return
		end

		local id: string

		runTransaction(options.dir, function(doc)
			id = resolveId(doc, parser:variadics()[1])
			removeItem(doc, id)
		end)

		options.write(`Removed {id}`)
	end,
})
