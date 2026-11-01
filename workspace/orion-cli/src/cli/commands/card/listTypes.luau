local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local getCardTypeRegistry = require("@root/canvas/cardTypes/getCardTypeRegistry")
local serializeCardType = require("@root/canvas/cardTypes/serializeCardType")

type Context = context.Context

return table.freeze({
	help = "List the card types this build knows, from Orion and from sources",
	mcp = { annotations = { readOnlyHint = true } },
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local items: json.Array = {}
		local lines: { string } = {}

		for _, cardType in getCardTypeRegistry().ordered do
			table.insert(items, serializeCardType(cardType))
			table.insert(lines, `{cardType.name}  {cardType.label}  ({cardType.pack})`)
		end

		options.write(if parser:has("json") then json.serialize(items, true) else table.concat(lines, "\n"))
	end,
})
