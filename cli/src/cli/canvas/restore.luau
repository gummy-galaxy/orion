local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local restoreWorkspace = require("@root/store/restoreWorkspace")

type Context = context.Context

return table.freeze({
	help = "Restore an archived canvas with its data",
	define = function(parser: cli.Parser)
		parser:add("name", "positional", { help = "Archived canvas name" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		restoreWorkspace(options.root, name)
		options.write(`Restored canvas {name}`)
	end,
})
