local cli = require("@batteries/cli")

local addFieldOptions = require("@root/cli/arguments/addFieldOptions")
local addIdPositional = require("@root/cli/arguments/addIdPositional")
local addRefOption = require("@root/cli/arguments/addRefOption")
local attachRequestedRef = require("@root/cli/arguments/attachRequestedRef")
local context = require("@root/cli/context")
local getItemFields = require("@root/cli/output/getItemFields")
local getRequired = require("@root/cli/arguments/getRequired")
local requireItem = require("@root/cli/edits/requireItem")
local resolveId = require("@root/canvas/query/resolveId")
local runTransaction = require("@root/storage/transactions/runTransaction")
local setFields = require("@root/canvas/items/setFields")
local types = require("@root/types")
local writeItem = require("@root/cli/output/writeItem")

type Context = context.Context
type Item = types.Item

return table.freeze({
	help = "Change an item's fields",
	mcp = {},
	define = function(parser: cli.Parser)
		addIdPositional(parser, "id")
		parser:add("label", "option", { help = "New label" })
		addFieldOptions(parser, true)
		addRefOption(parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local idInput = getRequired(parser, "id")
		local values = getItemFields(parser)

		local changed: Item
		local doc = runTransaction(options.dir, function(current)
			local id = resolveId(current, idInput)
			requireItem(current, id)
			changed = setFields(current, id, values)
			attachRequestedRef(current, id, parser:get("ref"))
		end)

		writeItem(options, doc, changed, "Updated")
	end,
})
