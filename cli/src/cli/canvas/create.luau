local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Create a canvas with its own data folder",
	define = function(parser: cli.Parser)
		parser:add("name", "positional", { help = "Canvas name. Omit it to derive one from --label" })
		parser:add("label", "option", { help = "Display label" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local list = store.createWorkspace(options.root, parser:get("name"), parser:get("label"))
		local created = list.workspaces[#list.workspaces]
		options.write(`Created canvas {created.name}`)
	end,
})
