local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local renameWorkspace = require("@root/store/renameWorkspace")

type Context = context.Context

return table.freeze({
	help = "Change a canvas's display label",
	define = function(parser: cli.Parser)
		parser:add("name", "positional", { help = "Canvas name" })
		parser:add("label", "positional", { help = "New display label" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		local label = assert(parser:get("label"), "missing <label>")
		renameWorkspace(options.root, name, label)
		options.write(`Renamed canvas {name} to {label}`)
	end,
})
