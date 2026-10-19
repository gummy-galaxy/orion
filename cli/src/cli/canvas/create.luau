local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local createWorkspace = require("@root/store/createWorkspace")
local writeResult = require("@root/cli/writeResult")

type Context = context.Context

return table.freeze({
	help = "Create a canvas with its own data folder",
	define = function(parser: cli.Parser)
		parser:add("name", "positional", { help = "Canvas name. Omit it to derive one from --label" })
		parser:add("label", "option", { help = "Display label" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local list = createWorkspace(options.root, parser:get("name"), parser:get("label"))
		local created = list.workspaces[#list.workspaces]
		writeResult(
			options,
			json.object({ name = created.name, label = created.label }),
			`Created canvas {created.name}`
		)
	end,
})
