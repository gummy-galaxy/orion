local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local writeResult = require("@root/cli/writeResult")

type Context = context.Context

return table.freeze({
	help = "Print where this canvas keeps its data",
	define = function(_parser: cli.Parser) end,

	run = function(_parser: cli.Parser, options: Context)
		writeResult(options, json.object({ path = options.dir }), options.dir)
	end,
})
