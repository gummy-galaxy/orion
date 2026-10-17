local cli = require("@batteries/cli")

local addBatchOptions = require("@root/cli/addBatchOptions")
local context = require("@root/cli/context")
local graph = require("@root/graph")
local isBatchEdit = require("@root/cli/isBatchEdit")
local runBatchEdit = require("@root/cli/runBatchEdit")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Dissolve groups, keeping their items in place",
	define = function(parser: cli.Parser)
		addBatchOptions(parser, "Group ids")
	end,

	run = function(parser: cli.Parser, options: Context)
		if isBatchEdit(parser) then
			runBatchEdit(parser, options, "ungroup")
			return
		end

		local id = parser:variadics()[1]

		store.transaction(options.dir, function(doc)
			graph.ungroup(doc, id)
		end)

		options.write(`Ungrouped {id}`)
	end,
})
