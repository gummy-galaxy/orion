local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Restore an archived workspace with its data",
	define = function(parser: cli.Parser)
		parser:add("name", "positional", { help = "Archived workspace name" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		store.restoreWorkspace(options.root, name)
		options.write(`Restored workspace {name}`)
	end,
})
