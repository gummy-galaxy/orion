local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "List canvases and mark the active one",
	define = function(parser: cli.Parser)
		parser:add("archived", "flag", { help = "List archived canvases instead" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local list = store.getWorkspaces(options.root)
		list.active = options.workspace
		local entries = if parser:has("archived") then list.archived else list.workspaces

		if parser:has("json") then
			local values: json.Array = {}

			for _, entry in entries do
				table.insert(values, json.object({ name = entry.name, label = entry.label }))
			end

			options.write(json.serialize(json.object({ active = list.active, workspaces = values }), true))
		else
			local lines = {}

			for _, entry in entries do
				table.insert(lines, `{if entry.name == list.active then "*" else " "} {entry.name} · {entry.label}`)
			end

			options.write(table.concat(lines, "\n"))
		end
	end,
})
