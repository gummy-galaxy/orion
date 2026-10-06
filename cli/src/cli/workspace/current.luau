local batteriesCli = require("@batteries/cli")

local context = require("@root/cli/context")

type Context = context.Context

return table.freeze({
	help = "Print the active workspace",
	define = function(_parser: batteriesCli.Parser) end,
	run = function(_parser: batteriesCli.Parser, options: Context)
		options.write(options.workspace)
	end,
})
