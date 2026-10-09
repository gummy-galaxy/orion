local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "List workspaces and mark the active one",
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local list = store.getWorkspaces(options.root)
		list.active = options.workspace

		if parser:has("json") then
			local entries: json.Array = {}

			for _, entry in list.workspaces do
				table.insert(entries, json.object({ name = entry.name, label = entry.label }))
			end

			options.write(json.serialize(json.object({ active = list.active, workspaces = entries }), true))
		else
			local lines = {}

			for _, entry in list.workspaces do
				table.insert(lines, `{if entry.name == list.active then "*" else " "} {entry.name} · {entry.label}`)
			end

			options.write(table.concat(lines, "\n"))
		end
	end,
})
