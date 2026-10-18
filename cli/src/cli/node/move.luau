local cli = require("@batteries/cli")

local addBatchOptions = require("@root/cli/addBatchOptions")
local context = require("@root/cli/context")
local isBatchEdit = require("@root/cli/isBatchEdit")
local moveItem = require("@root/graph/moveItem")
local resolveId = require("@root/query/resolveId")
local resolveOptionalId = require("@root/cli/resolveOptionalId")
local runBatchEdit = require("@root/cli/runBatchEdit")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Move items or groups into another group",
	define = function(parser: cli.Parser)
		addBatchOptions(parser, "Item or group ids or selectors")
		parser:add("to", "option", { help = "Destination group" })
		parser:add("top", "flag", { help = "Move to the top level" })
	end,

	run = function(parser: cli.Parser, options: Context)
		if isBatchEdit(parser) then
			runBatchEdit(parser, options, "move")
			return
		end

		local to = parser:get("to")
		assert(to or parser:has("top"), "say where with --to <group> or --top")

		local id: string
		local target: string?
		store.transaction(options.dir, function(doc)
			id = resolveId(doc, parser:variadics()[1])
			target = if parser:has("top") then nil else resolveOptionalId(doc, to)
			moveItem(doc, id, target)
		end)

		options.write(`Moved {id} to {target or "the top level"}`)
	end,
})
