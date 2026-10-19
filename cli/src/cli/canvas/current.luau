local cli = require("@batteries/cli")

local context = require("@root/cli/context")

type Context = context.Context

return table.freeze({
	help = "Print the active canvas",
	mcp = { skip = "reports the active canvas, which canvas list already marks" },
	define = function(_parser: cli.Parser) end,
	run = function(_parser: cli.Parser, options: Context)
		options.write(options.workspace)
	end,
})
