local cli = require("@batteries/cli")

local addArgument = require("@root/cli/arguments/addArgument")
local context = require("@root/cli/context")
local createGroup = require("@root/canvas/groups/createGroup")
local joinWords = require("@root/cli/output/joinWords")
local makeGroup = require("@root/canvas/groups/makeGroup")
local parseCommaList = require("@root/cli/arguments/parseCommaList")
local resolveId = require("@root/canvas/query/resolveId")
local runTransaction = require("@root/storage/transactions/runTransaction")
local types = require("@root/types")
local writeItem = require("@root/cli/output/writeItem")

type Context = context.Context
type Doc = types.Doc
type Item = types.Item

local function resolveIds(doc: Doc, inputs: { string }): { string }
	local ids: { string } = {}

	for _, input in inputs do
		table.insert(ids, resolveId(doc, input))
	end

	return ids
end

return table.freeze({
	help = "Make a group: empty, optionally inside another, or wrapping items that share a parent",
	mcp = {},
	define = function(parser: cli.Parser)
		addArgument(parser, "label", "variadic", { help = "Group name", type = "words" })
		addArgument(parser, "items", "option", {
			help = "Comma-separated ids to wrap; the group goes where they are",
			type = "commaList",
		})
		addArgument(parser, "in", "option", { help = "Group to make an empty group inside", type = "id" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local label = joinWords(parser:variadics(), "<label>")
		local itemsText = parser:get("items")
		local parent = parser:get("in")
		assert(not (itemsText and parent), "a group made from --items goes where they are, so it can't take --in")

		local made: Item
		local doc = runTransaction(options.dir, function(current)
			made = if itemsText
				then makeGroup(current, label, resolveIds(current, parseCommaList(itemsText)))
				else createGroup(current, label, parent)
		end)

		writeItem(options, doc, made, if itemsText then "Grouped into" else "Created group")
	end,
})
