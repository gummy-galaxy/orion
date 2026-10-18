local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local getRequired = require("@root/cli/getRequired")
local joinWords = require("@root/cli/joinWords")
local makeGroup = require("@root/graph/makeGroup")
local parseCommaList = require("@root/cli/parseCommaList")
local resolveId = require("@root/query/resolveId")
local store = require("@root/store")
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
	help = "Wrap items that share a parent in a new group",
	define = function(parser: cli.Parser)
		parser:add("label", "variadic", { help = "Group name" })
		parser:add("items", "option", { help = "Comma-separated ids to put in it (required)" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local label = joinWords(parser:variadics(), "<label>")
		local ids = parseCommaList(getRequired(parser, "items"))

		local made: Item
		local doc = store.transaction(options.dir, function(doc)
			made = makeGroup(doc, label, resolveIds(doc, ids))
		end)

		writeItem(options, doc, made, "Grouped into")
	end,
})
