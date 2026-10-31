local cli = require("@batteries/cli")

local addBatchOptions = require("@root/cli/arguments/addBatchOptions")
local context = require("@root/cli/context")
local isBatchEdit = require("@root/cli/edits/isBatchEdit")
local runBatchEdit = require("@root/cli/edits/runBatchEdit")
local runTransaction = require("@root/storage/transactions/runTransaction")
local ungroup = require("@root/canvas/groups/ungroup")

type Context = context.Context

return table.freeze({
	help = "Dissolve groups, keeping their items in place",
	mcp = {},
	define = function(parser: cli.Parser)
		addBatchOptions(parser, "Group ids or selectors")
	end,

	run = function(parser: cli.Parser, options: Context)
		if isBatchEdit(parser) then
			runBatchEdit(parser, options, "ungroup")
			return
		end

		local id = parser:variadics()[1]

		runTransaction(options.dir, function(doc)
			ungroup(doc, id)
		end)

		options.write(`Ungrouped {id}`)
	end,
})
