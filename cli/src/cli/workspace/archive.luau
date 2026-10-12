local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Archive a workspace. Its data stays in place, and restore brings it back",
	define = function(parser: cli.Parser)
		parser:add("name", "positional", { help = "Workspace name" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		store.archiveWorkspace(options.root, name, options.workspace)
		options.write(`Archived workspace {name}`)
	end,
})
