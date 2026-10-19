local cli = require("@batteries/cli")

local context = require("@root/cli/context")

type Context = context.Context

return table.freeze({
	help = "Print where this canvas keeps its data",
	mcp = { skip = "reports the local data folder, which tools have no use for" },
	define = function(_parser: cli.Parser) end,

	run = function(_parser: cli.Parser, options: Context)
		options.write(options.dir)
	end,
})
