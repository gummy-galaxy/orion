local cli = require("@batteries/cli")
local json = require("@std/json")
local process = require("@std/process")

local chooseTelemetry = require("@root/telemetry/chooseTelemetry")
local context = require("@root/cli/context")
local describeTelemetryStatus = require("@root/telemetry/describeTelemetryStatus")
local getTelemetryStatus = require("@root/telemetry/getTelemetryStatus")
local serializeTelemetryStatus = require("@root/telemetry/serializeTelemetryStatus")

type Context = context.Context

return table.freeze({
	help = "Stop sharing usage data, keeping the install id so shared data can still be deleted",
	mcp = { skip = "changes the person's consent, which only they should give" },
	define = function(_parser: cli.Parser) end,

	run = function(_parser: cli.Parser, options: Context)
		chooseTelemetry(options.root, false, "cli", process.env)

		local status = getTelemetryStatus(options.root, process.env)
		options.write(
			if options.asJson
				then json.serialize(serializeTelemetryStatus(status), true)
				else describeTelemetryStatus(status)
		)
	end,
})
