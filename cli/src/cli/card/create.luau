local cli = require("@batteries/cli")

local addArgument = require("@root/cli/addArgument")
local addFieldOptions = require("@root/cli/addFieldOptions")
local addItem = require("@root/graph/addItem")
local addRefOption = require("@root/cli/addRefOption")
local attachRequestedRef = require("@root/cli/attachRequestedRef")
local context = require("@root/cli/context")
local getItemFields = require("@root/cli/getItemFields")
local graphTypes = require("@root/graph/types")
local joinWords = require("@root/cli/joinWords")
local resolveOptionalId = require("@root/cli/resolveOptionalId")
local runTransaction = require("@root/store/runTransaction")
local types = require("@root/types")
local writeItem = require("@root/cli/writeItem")

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
		local doc = runTransaction(options.dir, function(doc)
			fields.group = resolveOptionalId(doc, groupInput)
			fields.after = resolveOptionalId(doc, parser:get("after"))
			fields.before = resolveOptionalId(doc, parser:get("before"))
			added = addItem(doc, label, fields)
			attachRequestedRef(doc, added.id, parser:get("ref"))
		end)

		writeItem(options, doc, added, "Added")
	end,
})
