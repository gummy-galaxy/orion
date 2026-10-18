local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local useWorkspace = require("@root/store/useWorkspace")

type Context = context.Context

return table.freeze({
	help = "Make a canvas the active one",
	define = function(parser: cli.Parser)
		parser:add("name", "positional", { help = "Canvas name" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		useWorkspace(options.root, name)
		options.write(`Using canvas {name}`)
	end,
})
