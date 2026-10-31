local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local getRegistry = require("@root/canvas/cardTypes/getRegistry")
local serializeRegistry = require("@root/canvas/cardTypes/serializeRegistry")

type Context = context.Context

return table.freeze({
	help = "List the card types this build knows, from Orion and from sources",
	mcp = { annotations = { readOnlyHint = true } },
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		if parser:has("json") then
			options.write(json.serialize(serializeRegistry(), true))
			return
		end

		local lines: { string } = {}

		for _, cardType in getRegistry().ordered do
			table.insert(lines, `{cardType.name}  {cardType.label}  ({cardType.pack})`)
		end

		options.write(table.concat(lines, "\n"))
	end,
})
