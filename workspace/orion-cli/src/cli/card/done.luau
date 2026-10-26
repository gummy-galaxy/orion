local cli = require("@batteries/cli")

local addBatchOptions = require("@root/cli/addBatchOptions")
local context = require("@root/cli/context")
local findState = require("@root/cardTypes/findState")
local getItem = require("@root/graph/getItem")
local getLabel = require("@root/graph/getLabel")
local isBatchEdit = require("@root/cli/isBatchEdit")
local requireItem = require("@root/cli/requireItem")
local resolveId = require("@root/query/resolveId")
local runBatchEdit = require("@root/cli/runBatchEdit")
local runTransaction = require("@root/store/runTransaction")
local setFields = require("@root/graph/setFields")

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
			setFields(current, id, { status = findState(getItem(current, id), "done") })
		end)

		options.write(`Done: {id} · {getLabel(getItem(doc, id))}`)
	end,
})
