local cli = require("@batteries/cli")

local batchEdit = require("@root/cli/batchEdit")
local context = require("@root/cli/context")
local parseUntil = require("@root/time/parseUntil")
local requestedRevision = require("@root/cli/requestedRevision")

type Context = context.Context

return table.freeze({
	help = "Hide items from attention and orion next until a time",
	define = function(parser: cli.Parser)
		parser:add("ids", "variadic", { help = "Item ids" })
		parser:add("until", "option", {
			help = "When it wakes: an ISO 8601 date or date-time, in local time unless it ends in Z or an offset",
			required = true,
		})
		parser:add("where", "option", { help = "Select items with an expression instead of ids" })
		parser:add("dry-run", "flag", { help = "Preview changes and current revision without writing" })
		parser:add("if-revision", "option", { help = "Write only if the document has this revision" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local untilTime = parseUntil(assert(parser:get("until"), "missing --until"))
		local now = options.now()
		assert(untilTime > now, `--until must be later than now ({now})`)

		batchEdit({
			dir = options.dir,
			action = "snooze",
			ids = parser:variadics(),
			where = parser:get("where"),
			dryRun = parser:has("dry-run"),
			asJson = options.asJson,
			ifRevision = requestedRevision(parser),
			untilTime = untilTime,
			now = now,
			write = options.write,
		})
	end,
})
