local cli = require("@batteries/cli")

local addBatchOptions = require("@root/cli/addBatchOptions")
local context = require("@root/cli/context")
local graph = require("@root/graph")
local isBatchEdit = require("@root/cli/isBatchEdit")
local requireItem = require("@root/cli/requireItem")
local runBatchEdit = require("@root/cli/runBatchEdit")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Mark one or more items done",
	define = function(parser: cli.Parser)
		addBatchOptions(parser, "Item ids")
	end,

	run = function(parser: cli.Parser, options: Context)
		if isBatchEdit(parser) then
			runBatchEdit(parser, options, "done")
			return
		end

		local id = parser:variadics()[1]
		local doc = store.transaction(options.dir, function(doc)
			requireItem(doc, id)
			graph.setFields(doc, id, { status = "done" })
		end)

		options.write(`Done: {id} · {graph.label(graph.get(doc, id))}`)
	end,
})
