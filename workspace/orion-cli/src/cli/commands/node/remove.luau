local cli = require("@batteries/cli")

local addBatchOptions = require("@root/cli/arguments/addBatchOptions")
local context = require("@root/cli/context")
local isBatchEdit = require("@root/cli/edits/isBatchEdit")
local removeItem = require("@root/canvas/items/removeItem")
local resolveId = require("@root/canvas/query/resolveId")
local runBatchEdit = require("@root/cli/edits/runBatchEdit")
local runTransaction = require("@root/storage/transactions/runTransaction")

type Context = context.Context

return table.freeze({
	help = "Remove items. Removing a note reconnects the links that ran through it",
	mcp = { annotations = { destructiveHint = true } },
	define = function(parser: cli.Parser)
		addBatchOptions(parser, "Item ids or selectors")
		parser:add("reconnect", "flag", {
			help = "Also reconnect cards with at most one incoming and one outgoing link; "
				.. "every selected card must qualify",
		})
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
