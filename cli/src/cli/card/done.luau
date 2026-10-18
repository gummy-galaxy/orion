local cli = require("@batteries/cli")

local addBatchOptions = require("@root/cli/addBatchOptions")
local context = require("@root/cli/context")
local getItem = require("@root/graph/getItem")
local getLabel = require("@root/graph/getLabel")
local isBatchEdit = require("@root/cli/isBatchEdit")
local requireItem = require("@root/cli/requireItem")
local resolveId = require("@root/query/resolveId")
local runBatchEdit = require("@root/cli/runBatchEdit")
local setFields = require("@root/graph/setFields")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Mark one or more items done",
	define = function(parser: cli.Parser)
		addBatchOptions(parser, "Item ids or selectors")
	end,

	run = function(parser: cli.Parser, options: Context)
		if isBatchEdit(parser) then
			runBatchEdit(parser, options, "done")
			return
		end

		local id: string
		local doc = store.transaction(options.dir, function(doc)
			id = resolveId(doc, parser:variadics()[1])
			requireItem(doc, id)
			setFields(doc, id, { status = "done" })
		end)

		options.write(`Done: {id} · {getLabel(getItem(doc, id))}`)
	end,
})
