local cli = require("@batteries/cli")
local json = require("@std/json")

local addArgument = require("@root/cli/addArgument")
local archiveWorkspace = require("@root/store/archiveWorkspace")
local context = require("@root/cli/context")
local writeResult = require("@root/cli/writeResult")

type Context = context.Context

return table.freeze({
	help = "Archive a canvas. Its data stays in place, and restore brings it back. "
		.. "The active canvas and default can't be archived",
	mcp = { omit = { { option = "canvas", reason = "names the canvas it archives" } } },
	define = function(parser: cli.Parser)
		addArgument(parser, "name", "positional", { help = "Canvas name", type = "canvas" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		archiveWorkspace(options.root, name, options.workspace)
		writeResult(options, json.object({ name = name }), `Archived canvas {name}`)
	end,
})
