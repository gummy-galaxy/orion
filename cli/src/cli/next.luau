local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local graph = require("@root/graph")
local sortTasks = require("@root/cli/sortTasks")
local store = require("@root/store")
local writeItems = require("@root/cli/writeItems")

type Context = context.Context

return table.freeze({
	help = "List items that can start now, most unblocking first",
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(_parser: cli.Parser, options: Context)
		local doc = store.load(options.dir)
		local derived = graph.derive(doc, options.now())
		local items = sortTasks(doc, derived, function(item)
			local status = derived.status[item.id]
			return graph.isWork(item)
				and not derived.snoozed[item.id]
				and (status == "ready" or status == "active" or status == "review")
		end)

		writeItems(options, doc, derived, items)
	end,
})
