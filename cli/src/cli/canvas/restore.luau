local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local restoreWorkspace = require("@root/store/restoreWorkspace")
local writeResult = require("@root/cli/writeResult")

type Context = context.Context

return table.freeze({
	help = "Restore an archived canvas with its data",
	define = function(parser: cli.Parser)
		parser:add("name", "positional", { help = "Archived canvas name" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		restoreWorkspace(options.root, name)
		writeResult(options, json.object({ name = name }), `Restored canvas {name}`)
	end,
})
