local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Change a workspace's display label",
	define = function(parser: cli.Parser)
		parser:add("name", "positional", { help = "Workspace name" })
		parser:add("label", "positional", { help = "New display label" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		local label = assert(parser:get("label"), "missing <label>")
		store.renameWorkspace(options.root, name, label)
		options.write(`Renamed workspace {name} to {label}`)
	end,
})
