local cli = require("@batteries/cli")

local addBatchOptions = require("@root/cli/addBatchOptions")
local context = require("@root/cli/context")
local graph = require("@root/graph")
local isBatchEdit = require("@root/cli/isBatchEdit")
local runBatchEdit = require("@root/cli/runBatchEdit")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Move items or groups into another group",
	define = function(parser: cli.Parser)
		addBatchOptions(parser, "Item or group ids")
		parser:add("to", "option", { help = "Destination group" })
		parser:add("top", "flag", { help = "Move to the top level" })
	end,

	run = function(parser: cli.Parser, options: Context)
		if isBatchEdit(parser) then
			runBatchEdit(parser, options, "move")
			return
		end

		local id = parser:variadics()[1]
		local to = parser:get("to")
		assert(to or parser:has("top"), "say where with --to <group> or --top")

		store.transaction(options.dir, function(doc)
			graph.move(doc, id, if parser:has("top") then nil else to)
		end)

		options.write(`Moved {id} to {to or "the top level"}`)
	end,
})
