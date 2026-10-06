local batteriesCli = require("@batteries/cli")

local context = require("@root/cli/context")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Make a workspace the active one",
	define = function(parser: batteriesCli.Parser)
		parser:add("name", "positional", { help = "Workspace name" })
	end,
	run = function(parser: batteriesCli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		store.useWorkspace(options.root, name)
		options.write(`Using workspace {name}`)
	end,
})
