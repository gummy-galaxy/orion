local cli = require("@batteries/cli")

local addFieldOptions = require("@root/cli/addFieldOptions")
local addIdPositional = require("@root/cli/addIdPositional")
local addRefOption = require("@root/cli/addRefOption")
local attachRequestedRef = require("@root/cli/attachRequestedRef")
local context = require("@root/cli/context")
local getItemFields = require("@root/cli/getItemFields")
local getRequired = require("@root/cli/getRequired")
local requireItem = require("@root/cli/requireItem")
local resolveId = require("@root/query/resolveId")
local setFields = require("@root/graph/setFields")
local store = require("@root/store")
local types = require("@root/types")
local writeItem = require("@root/cli/writeItem")

type Context = context.Context
type Item = types.Item

return table.freeze({
	help = "Change an item's fields",
	define = function(parser: cli.Parser)
		addIdPositional(parser, "id")
		parser:add("label", "option", { help = "New label" })
		addFieldOptions(parser)
		addRefOption(parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local idInput = getRequired(parser, "id")
		local values = getItemFields(parser)

		local changed: Item
		local doc = store.transaction(options.dir, function(doc)
			local id = resolveId(doc, idInput)
			requireItem(doc, id)
			changed = setFields(doc, id, values)
			attachRequestedRef(doc, id, parser:get("ref"))
		end)

		writeItem(options, doc, changed, "Updated")
	end,
})
