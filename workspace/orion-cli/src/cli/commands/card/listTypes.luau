local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local getCardTypeRegistry = require("@root/canvas/cardTypes/getCardTypeRegistry")
local serializeCardTypeRegistry = require("@root/canvas/cardTypes/serializeCardTypeRegistry")

type Context = context.Context

return table.freeze({
	help = "List the card types this build knows, from Orion and from sources",
	mcp = { annotations = { readOnlyHint = true } },
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		if parser:has("json") then
			options.write(json.serialize(serializeCardTypeRegistry(), true))
			return
		end

		local lines: { string } = {}

		for _, cardType in getCardTypeRegistry().ordered do
			table.insert(lines, `{cardType.name}  {cardType.label}  ({cardType.pack})`)
		end

		options.write(table.concat(lines, "\n"))
	end,
})
