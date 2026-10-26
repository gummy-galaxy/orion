local cli = require("@batteries/cli")
local json = require("@std/json")

local addArgument = require("@root/cli/addArgument")
local batchEdit = require("@root/cli/batchEdit")
local context = require("@root/cli/context")
local getRunningRuntime = require("@root/server/getRunningRuntime")
local isProcessAlive = require("@root/server/isProcessAlive")
local requestedRevision = require("@root/cli/requestedRevision")

type Context = context.Context

-- The app connects through orion server start, so a running server stands in
-- for an open app.
local function isServing(options: Context): boolean
	return getRunningRuntime(options.root, function(pid)
		return isProcessAlive(pid, options.runner)
	end) ~= nil
end

return table.freeze({
	help = "Mark groups for the app to lay out in place",
	mcp = {
		description = "Mark groups for the app to lay out in place, deepest first, such as after adding cards in bulk. The app does the layout, so appConnected in the result says whether it runs now or when the app next opens. Custom groups keep their arrangement.",
	},
	define = function(parser: cli.Parser)
		parser:add("ids", "variadic", { help = "Group ids" })
		parser:add("where", "option", { help = "Select groups with an expression instead of ids" })
		parser:add("dry-run", "flag", { help = "Preview changes and current revision without writing" })
		addArgument(parser, "if-revision", "option", {
			help = "Write only if the document has this revision",
			type = "integer",
			minimum = 0,
		})
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local dryRun = parser:has("dry-run")
		local connected = isServing(options)
		local note: string? = nil

		if not dryRun then
			note = if connected
				then "The app lays them out when it picks up the change."
				else "No app is connected, so the layout runs when the app opens."
		end

		batchEdit({
			dir = options.dir,
			action = "tidy",
			ids = parser:variadics(),
			where = parser:get("where"),
			dryRun = dryRun,
			asJson = options.asJson,
			ifRevision = requestedRevision(parser),
			note = note,
			extra = json.object({ appConnected = connected }),
			write = options.write,
		})
	end,
})
