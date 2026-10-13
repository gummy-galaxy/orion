local cli = require("@batteries/cli")

local applyCanvasStyle = require("@root/style/applyCanvasStyle")
local context = require("@root/cli/context")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Set a canvas's cover or background",
	define = function(parser: cli.Parser)
		parser:add(
			"cover",
			"option",
			{ help = "Image asset id for the cover, from orion media insert --json (empty to clear)" }
		)
		parser:add(
			"background",
			"option",
			{ help = "Color, color token such as card.background, or image asset id (empty to clear)" }
		)
		parser:add(
			"header",
			"option",
			{ help = "Markdown with layout HTML shown over the top of the canvas (empty to clear)" }
		)
	end,

	run = function(parser: cli.Parser, options: Context)
		local cover = parser:get("cover")
		local background = parser:get("background")
		local header = parser:get("header")
		assert(cover ~= nil or background ~= nil or header ~= nil, "give --cover, --background, or --header")
		store.transaction(options.dir, function(doc)
			applyCanvasStyle(doc, options.dir, { cover = cover, background = background, header = header })
		end)
		options.write(`Updated workspace {options.workspace}`)
	end,
})
