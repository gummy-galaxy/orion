local cli = require("@batteries/cli")
local json = require("@std/json")
local process = require("@std/process")

local context = require("@root/cli/context")
local deleteTelemetryDataAsync = require("@root/telemetry/deleteTelemetryDataAsync")

type Context = context.Context

local MESSAGES = {
	deleted = "Deleted the usage data this machine shared. It can take a few days to disappear, and sharing is now off.",
	nothing = "This machine hasn't shared any usage data, so there's nothing to delete.",
}

return table.freeze({
	help = "Delete the usage data this machine has shared, and stop sharing",
	mcp = { skip = "deletes the person's shared data, which only they should choose" },
	define = function(_parser: cli.Parser) end,

	run = function(_parser: cli.Parser, options: Context)
		local outcome, failure = deleteTelemetryDataAsync(options.root, { environment = process.env })

		if outcome == "failed" then
			error(
				`Couldn't delete the usage data this machine shared, because {failure}. Sharing is off. Try again later.`,
				0
			)
		end

		options.write(
			if options.asJson
				then json.serialize(json.object({ deleted = outcome == "deleted" }), true)
				else MESSAGES[outcome]
		)
	end,
})
