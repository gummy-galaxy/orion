local cli = require("@batteries/cli")
local json = require("@std/json")

local addArgument = require("@root/cli/arguments/addArgument")
local context = require("@root/cli/context")
local useWorkspace = require("@root/storage/canvases/useWorkspace")
local writeResult = require("@root/cli/output/writeResult")

type Context = context.Context

return table.freeze({
	help = "Make a canvas the active one",
	mcp = { omit = { { option = "canvas", reason = "names the canvas it selects" } } },
	define = function(parser: cli.Parser)
		addArgument(parser, "name", "positional", { help = "Canvas name", type = "canvas" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		useWorkspace(options.root, name)
		writeResult(options, json.object({ name = name }), `Using canvas {name}`)
	end,
})
