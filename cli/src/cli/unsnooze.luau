local cli = require("@batteries/cli")

local batchEdit = require("@root/cli/batchEdit")
local batchOptions = require("@root/cli/batchOptions")
local context = require("@root/cli/context")

type Context = context.Context

return table.freeze({
	help = "Show snoozed items again right away",
	define = function(parser: cli.Parser)
		batchOptions.define(parser, "Item ids")
	end,

	run = function(parser: cli.Parser, options: Context)
		batchEdit({
			dir = options.dir,
			action = "unsnooze",
			ids = parser:variadics(),
			where = parser:get("where"),
			dryRun = parser:has("dry-run"),
			asJson = options.asJson,
			ifRevision = batchOptions.readRevision(parser),
			write = options.write,
		})
	end,
})
