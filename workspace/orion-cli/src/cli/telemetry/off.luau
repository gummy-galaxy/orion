local cli = require("@batteries/cli")
local json = require("@std/json")
local process = require("@std/process")

local chooseTelemetry = require("@root/telemetry/chooseTelemetry")
local context = require("@root/cli/context")
local describeStatus = require("@root/telemetry/describeStatus")
local getStatus = require("@root/telemetry/getStatus")
local serializeStatus = require("@root/telemetry/serializeStatus")

type Context = context.Context

return table.freeze({
	help = "Stop sharing usage data and delete this machine's install id",
	mcp = { skip = "changes the person's consent, which only they should give" },
	define = function(_parser: cli.Parser) end,

	run = function(_parser: cli.Parser, options: Context)
		chooseTelemetry(options.root, false, "cli", process.env)

		local status = getStatus(options.root, process.env)
		options.write(if options.asJson then json.serialize(serializeStatus(status), true) else describeStatus(status))
	end,
})
