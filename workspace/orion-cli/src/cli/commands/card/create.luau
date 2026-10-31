local cli = require("@batteries/cli")

local addArgument = require("@root/cli/arguments/addArgument")
local addFieldOptions = require("@root/cli/arguments/addFieldOptions")
local addItem = require("@root/canvas/items/addItem")
local addRefOption = require("@root/cli/arguments/addRefOption")
local attachRequestedRef = require("@root/cli/arguments/attachRequestedRef")
local context = require("@root/cli/context")
local getItemFields = require("@root/cli/output/getItemFields")
local graphTypes = require("@root/canvas/types")
local joinWords = require("@root/cli/output/joinWords")
local resolveOptionalId = require("@root/cli/arguments/resolveOptionalId")
local runTransaction = require("@root/storage/transactions/runTransaction")
local types = require("@root/types")
local writeItem = require("@root/cli/output/writeItem")

type Context = context.Context
type Item = types.Item

return table.freeze({
	help = "Add a work item",
	mcp = {},
	define = function(parser: cli.Parser)
		addArgument(parser, "label", "variadic", { help = "What the work is", type = "words" })
		addArgument(parser, "group", "option", { help = "Group to add it to", type = "id" })
		addArgument(
			parser,
			"after",
			"option",
			{ help = "Item the card follows; it lands beside it, in its group", type = "id" }
		)
		addArgument(
			parser,
			"before",
			"option",
			{ help = "Item the card leads into; it lands beside it, in its group", type = "id" }
		)
		addFieldOptions(parser, false)
		addRefOption(parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local label = joinWords(parser:variadics(), "<label>")
		local fields = getItemFields(parser) :: graphTypes.AddOptions
		local groupInput = parser:get("group")

		local added: Item
		local doc = runTransaction(options.dir, function(current)
			fields.group = resolveOptionalId(current, groupInput)
			fields.after = resolveOptionalId(current, parser:get("after"))
			fields.before = resolveOptionalId(current, parser:get("before"))
			added = addItem(current, label, fields)
			attachRequestedRef(current, added.id, parser:get("ref"))
		end)

		writeItem(options, doc, added, "Added")
	end,
})
