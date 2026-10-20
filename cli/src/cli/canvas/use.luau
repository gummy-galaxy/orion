local cli = require("@batteries/cli")

local addArgument = require("@root/cli/addArgument")
local context = require("@root/cli/context")
local useWorkspace = require("@root/store/useWorkspace")

type Context = context.Context

return table.freeze({
	help = "Make a canvas the active one",
	mcp = { omit = { { option = "canvas", reason = "names the canvas it selects" } } },
	define = function(parser: cli.Parser)
		addArgument(parser, "name", "positional", { help = "Canvas name", type = "canvas" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		useWorkspace(options.root, name)
		options.write(`Using canvas {name}`)
	end,
})
