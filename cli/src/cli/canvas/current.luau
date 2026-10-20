local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local writeResult = require("@root/cli/writeResult")

type Context = context.Context

return table.freeze({
	help = "Print the active canvas",
	mcp = { skip = "reports the active canvas, which canvas list already marks" },
	define = function(_parser: cli.Parser) end,
	run = function(_parser: cli.Parser, options: Context)
		writeResult(options, json.object({ name = options.workspace }), options.workspace)
	end,
})
