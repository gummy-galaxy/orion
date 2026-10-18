local cli = require("@batteries/cli")

local addFieldOptions = require("@root/cli/addFieldOptions")
local addRefOption = require("@root/cli/addRefOption")
local attachRequestedRef = require("@root/cli/attachRequestedRef")
local context = require("@root/cli/context")
local getItemFields = require("@root/cli/getItemFields")
local graph = require("@root/graph")
local joinWords = require("@root/cli/joinWords")
local resolveOptionalId = require("@root/cli/resolveOptionalId")
local store = require("@root/store")
local types = require("@root/types")
local writeItem = require("@root/cli/writeItem")

type Context = context.Context
type Item = types.Item

return table.freeze({
	help = "Add a work item",
	define = function(parser: cli.Parser)
		parser:add("label", "variadic", { help = "What the work is" })
		parser:add("group", "option", { help = "Group to add it to" })
		addFieldOptions(parser)
		addRefOption(parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local label = joinWords(parser:variadics(), "<label>")
		local fields = getItemFields(parser) :: graph.AddOptions
		local groupInput = parser:get("group")

		local added: Item
		local doc = store.transaction(options.dir, function(doc)
			fields.group = resolveOptionalId(doc, groupInput)
			added = graph.addItem(doc, label, fields)
			attachRequestedRef(doc, added.id, parser:get("ref"))
		end)

		writeItem(options, doc, added, "Added")
	end,
})
