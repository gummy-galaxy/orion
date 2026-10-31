local cli = require("@batteries/cli")
local json = require("@std/json")

local addArgument = require("@root/cli/arguments/addArgument")
local context = require("@root/cli/context")
local restoreWorkspace = require("@root/storage/canvases/restoreWorkspace")
local writeResult = require("@root/cli/output/writeResult")

type Context = context.Context

return table.freeze({
	help = "Restore an archived canvas with its data",
	mcp = { omit = { { option = "canvas", reason = "names the canvas it restores" } } },
	define = function(parser: cli.Parser)
		addArgument(parser, "name", "positional", { help = "Archived canvas name", type = "canvas" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		restoreWorkspace(options.root, name)
		writeResult(options, json.object({ name = name }), `Restored canvas {name}`)
	end,
})
