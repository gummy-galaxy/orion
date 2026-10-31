local cli = require("@batteries/cli")

local addArgument = require("@root/cli/arguments/addArgument")
local addBatchOptions = require("@root/cli/arguments/addBatchOptions")
local context = require("@root/cli/context")
local isBatchEdit = require("@root/cli/edits/isBatchEdit")
local moveItem = require("@root/canvas/placement/moveItem")
local resolveId = require("@root/canvas/query/resolveId")
local resolveOptionalId = require("@root/cli/arguments/resolveOptionalId")
local runBatchEdit = require("@root/cli/edits/runBatchEdit")
local runTransaction = require("@root/storage/transactions/runTransaction")

type Context = context.Context

return table.freeze({
	help = "Move items or groups into another group",
	mcp = {},
	define = function(parser: cli.Parser)
		addBatchOptions(parser, "Item or group ids or selectors")
		addArgument(parser, "to", "option", { help = "Destination group", type = "id" })
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
		runTransaction(options.dir, function(doc)
			id = resolveId(doc, parser:variadics()[1])
			target = if parser:has("top") then nil else resolveOptionalId(doc, to)
			moveItem(doc, id, target)
		end)

		options.write(`Moved {id} to {target or "the top level"}`)
	end,
})
