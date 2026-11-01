local cli = require("@batteries/cli")
local json = require("@std/json")
local process = require("@std/process")

local context = require("@root/cli/context")
local describeTelemetryStatus = require("@root/telemetry/describeTelemetryStatus")
local getTelemetryStatus = require("@root/telemetry/getTelemetryStatus")
local serializeTelemetryStatus = require("@root/telemetry/serializeTelemetryStatus")

type Context = context.Context

return table.freeze({
	help = "Show whether this machine shares anonymous usage data",
	mcp = { annotations = { readOnlyHint = true } },
	define = function(_parser: cli.Parser) end,

	run = function(_parser: cli.Parser, options: Context)
		local status = getTelemetryStatus(options.root, process.env)

		options.write(
			if options.asJson
				then json.serialize(serializeTelemetryStatus(status), true)
				else describeTelemetryStatus(status)
		)
	end,
})
