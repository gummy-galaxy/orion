local cli = require("@batteries/cli")

local batchEdit = require("@root/cli/batchEdit")
local batchOptions = require("@root/cli/batchOptions")
local context = require("@root/cli/context")
local parseUntil = require("@root/time/parseUntil")

type Context = context.Context

return table.freeze({
	help = "Hide items from attention and ready lists until a time",
	define = function(parser: cli.Parser)
		batchOptions.define(parser, "Item ids")
		parser:add("until", "option", { help = "When it wakes: an ISO 8601 date or date-time", required = true })
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
			ifRevision = batchOptions.readRevision(parser),
			untilTime = untilTime,
			write = options.write,
		})
	end,
})
