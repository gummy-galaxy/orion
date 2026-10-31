local cli = require("@batteries/cli")

local addBatchOptions = require("@root/cli/arguments/addBatchOptions")
local context = require("@root/cli/context")
local getItem = require("@root/canvas/items/getItem")
local getLabel = require("@root/canvas/items/getLabel")
local isBatchEdit = require("@root/cli/edits/isBatchEdit")
local requireItem = require("@root/cli/edits/requireItem")
local resolveId = require("@root/canvas/query/resolveId")
local runBatchEdit = require("@root/cli/edits/runBatchEdit")
local runTransaction = require("@root/storage/transactions/runTransaction")
local setFields = require("@root/canvas/items/setFields")

type Context = context.Context

return table.freeze({
	help = "Mark one or more items done",
	mcp = {},
	define = function(parser: cli.Parser)
		addBatchOptions(parser, "Item ids or selectors")
	end,

	run = function(parser: cli.Parser, options: Context)
		if isBatchEdit(parser) then
			runBatchEdit(parser, options, "done")
			return
		end

		local id: string
		local doc = runTransaction(options.dir, function(current)
			id = resolveId(current, parser:variadics()[1])
			requireItem(current, id)
			setFields(current, id, { status = "done" })
		end)

		options.write(`Done: {id} · {getLabel(getItem(doc, id))}`)
	end,
})
