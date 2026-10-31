local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local derive = require("@root/canvas/derive")
local isWork = require("@root/canvas/items/isWork")
local loadDoc = require("@root/storage/canvases/loadDoc")
local sortTasks = require("@root/cli/output/sortTasks")
local writeItems = require("@root/cli/output/writeItems")

type Context = context.Context

return table.freeze({
	help = "List items that can start now, most unblocking first",
	mcp = { annotations = { readOnlyHint = true } },
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(_parser: cli.Parser, options: Context)
		local doc = loadDoc(options.dir)
		local derived = derive(doc, options.now())
		local items = sortTasks(doc, derived, function(item)
			local status = derived.status[item.id]
			return isWork(item)
				and not derived.snoozed[item.id]
				and (status == "ready" or status == "active" or status == "review")
		end)

		writeItems(options, doc, derived, items)
	end,
})
