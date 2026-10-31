local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local removeThemeFile = require("@root/canvas/appearance/removeThemeFile")

type Context = context.Context

return table.freeze({
	help = "Delete a theme file from the data folder",
	mcp = { annotations = { destructiveHint = true } },
	define = function(parser: cli.Parser)
		parser:add("file", "positional", { help = "Theme file name, as theme list shows it" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,
	run = function(parser: cli.Parser, options: Context)
		local name = removeThemeFile(options.root, assert(parser:get("file"), "file is required"))

		if parser:has("json") then
			options.write(json.serialize(json.object({ file = name }), true))
		else
			options.write(`Removed theme {name}`)
		end
	end,
})
