local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Create a workspace with its own data folder",
	define = function(parser: cli.Parser)
		parser:add("name", "positional", { help = "Workspace name" })
		parser:add("label", "option", { help = "Display label" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		store.createWorkspace(options.root, name, parser:get("label"))
		options.write(`Created workspace {name}`)
	end,
})
