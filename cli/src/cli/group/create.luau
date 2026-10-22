local cli = require("@batteries/cli")

local addArgument = require("@root/cli/addArgument")
local context = require("@root/cli/context")
local createGroup = require("@root/graph/createGroup")
local joinWords = require("@root/cli/joinWords")
local makeGroup = require("@root/graph/makeGroup")
local parseCommaList = require("@root/cli/parseCommaList")
local resolveId = require("@root/query/resolveId")
local runTransaction = require("@root/store/runTransaction")
local types = require("@root/types")
local writeItem = require("@root/cli/writeItem")

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
		local doc = runTransaction(options.dir, function(doc)
			made = if itemsText
				then makeGroup(doc, label, resolveIds(doc, parseCommaList(itemsText)))
				else createGroup(doc, label, parent)
		end)

		writeItem(options, doc, made, if itemsText then "Grouped into" else "Created group")
	end,
})
