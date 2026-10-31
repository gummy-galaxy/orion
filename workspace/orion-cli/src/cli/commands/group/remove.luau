local cli = require("@batteries/cli")

local addBatchOptions = require("@root/cli/arguments/addBatchOptions")
local context = require("@root/cli/context")
local runBatchEdit = require("@root/cli/edits/runBatchEdit")

type Context = context.Context

return table.freeze({
	help = "Remove groups with everything inside them",
	mcp = { annotations = { destructiveHint = true } },
	define = function(parser: cli.Parser)
		addBatchOptions(parser, "Group ids or selectors")
	end,

	run = function(parser: cli.Parser, options: Context)
		runBatchEdit(parser, options, "removeGroup")
	end,
})
