local cli = require("@batteries/cli")

local addArgument = require("@root/cli/arguments/addArgument")
local addIdPositional = require("@root/cli/arguments/addIdPositional")
local attachCardType = require("@root/canvas/cardTypes/attachCardType")
local context = require("@root/cli/context")
local getRequired = require("@root/cli/arguments/getRequired")
local resolveId = require("@root/canvas/query/resolveId")
local runTransaction = require("@root/storage/transactions/runTransaction")
local types = require("@root/types")
local writeItem = require("@root/cli/output/writeItem")

type Context = context.Context
type Item = types.Item

return table.freeze({
	help = "Attach a card type to a card, after the ones it carries",
	mcp = {},
	define = function(parser: cli.Parser)
		addIdPositional(parser, "id")
		addArgument(parser, "type", "positional", { help = "The type's name, as orion card types shows it" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local idInput = getRequired(parser, "id")
		local name = getRequired(parser, "type")

		local changed: Item
		local doc = runTransaction(options.dir, function(current)
			changed = attachCardType(current, resolveId(current, idInput), name)
		end)

		writeItem(options, doc, changed, "Updated")
	end,
})
