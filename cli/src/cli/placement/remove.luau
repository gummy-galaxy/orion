local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local getRequired = require("@root/cli/getRequired")
local removePlacement = require("@root/graph/removePlacement")
local runTransaction = require("@root/store/runTransaction")

type Context = context.Context

return table.freeze({
	help = "Take one copy of a card off the canvas and keep the card. Use node remove to delete the card everywhere",
	define = function(parser: cli.Parser)
		parser:add(
			"id",
			"positional",
			{ help = "Placement id from placement list, or the card's id for its first place" }
		)
	end,

	run = function(parser: cli.Parser, options: Context)
		local id = getRequired(parser, "id")

		runTransaction(options.dir, function(doc)
			removePlacement(doc, id)
		end)

		options.write(`Removed placement {id}`)
	end,
})
