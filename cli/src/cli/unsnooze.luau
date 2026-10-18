local cli = require("@batteries/cli")

local batchEdit = require("@root/cli/batchEdit")
local context = require("@root/cli/context")
local requestedRevision = require("@root/cli/requestedRevision")

type Context = context.Context

return table.freeze({
	help = "Show snoozed items again right away",
	define = function(parser: cli.Parser)
		parser:add("ids", "variadic", { help = "Item ids" })
		parser:add("where", "option", { help = "Select items with an expression instead of ids" })
		parser:add("dry-run", "flag", { help = "Preview changes and current revision without writing" })
		parser:add("if-revision", "option", { help = "Write only if the document has this revision" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		batchEdit({
			dir = options.dir,
			action = "unsnooze",
			ids = parser:variadics(),
			where = parser:get("where"),
			dryRun = parser:has("dry-run"),
			asJson = options.asJson,
			ifRevision = requestedRevision(parser),
			now = options.now(),
			write = options.write,
		})
	end,
})
