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
	end,

	run = function(parser: cli.Parser, options: Context)
		local cover = parser:get("cover")
		local background = parser:get("background")
		assert(cover ~= nil or background ~= nil, "give --cover or --background")
		store.transaction(options.dir, function(doc)
			applyCanvasStyle(doc, options.dir, { cover = cover, background = background })
		end)
		options.write(`Updated canvas {options.workspace}`)
	end,
})
