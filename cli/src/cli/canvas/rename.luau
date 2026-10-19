local cli = require("@batteries/cli")
local json = require("@std/json")

local addArgument = require("@root/cli/addArgument")
local context = require("@root/cli/context")
local renameWorkspace = require("@root/store/renameWorkspace")
local writeResult = require("@root/cli/writeResult")

type Context = context.Context

return table.freeze({
	help = "Change a canvas's display label",
	mcp = { omit = { { option = "canvas", reason = "names the canvas it renames" } } },
	define = function(parser: cli.Parser)
		addArgument(parser, "name", "positional", { help = "Canvas name", type = "canvas" })
		parser:add("label", "positional", { help = "New display label" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		local label = assert(parser:get("label"), "missing <label>")
		renameWorkspace(options.root, name, label)
		writeResult(options, json.object({ name = name, label = label }), `Renamed canvas {name} to {label}`)
	end,
})
