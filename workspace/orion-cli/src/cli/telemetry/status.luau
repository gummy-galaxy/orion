local cli = require("@batteries/cli")
local json = require("@std/json")
local process = require("@std/process")

local context = require("@root/cli/context")
local describeStatus = require("@root/telemetry/describeStatus")
local getStatus = require("@root/telemetry/getStatus")
local serializeStatus = require("@root/telemetry/serializeStatus")

type Context = context.Context

return table.freeze({
	help = "Show whether this machine shares anonymous usage data",
	mcp = { annotations = { readOnlyHint = true } },
	define = function(_parser: cli.Parser) end,

	run = function(_parser: cli.Parser, options: Context)
		local status = getStatus(options.root, process.env)

		options.write(if options.asJson then json.serialize(serializeStatus(status), true) else describeStatus(status))
	end,
})
