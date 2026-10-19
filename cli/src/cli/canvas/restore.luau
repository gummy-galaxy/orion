local cli = require("@batteries/cli")

local addArgument = require("@root/cli/addArgument")
local context = require("@root/cli/context")
local restoreWorkspace = require("@root/store/restoreWorkspace")

type Context = context.Context

return table.freeze({
	help = "Restore an archived canvas with its data",
	mcp = { omit = { { option = "canvas", reason = "names the canvas it restores" } } },
	define = function(parser: cli.Parser)
		addArgument(parser, "name", "positional", { help = "Archived canvas name", type = "canvas" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		restoreWorkspace(options.root, name)
		options.write(`Restored canvas {name}`)
	end,
})
