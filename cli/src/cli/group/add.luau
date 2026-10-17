local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local getRequired = require("@root/cli/getRequired")
local graph = require("@root/graph")
local joinWords = require("@root/cli/joinWords")
local parseCommaList = require("@root/cli/parseCommaList")
local store = require("@root/store")
local types = require("@root/types")
local writeItem = require("@root/cli/writeItem")

type Context = context.Context
type Item = types.Item

return table.freeze({
	help = "Wrap items that share a parent in a new group",
	define = function(parser: cli.Parser)
		parser:add("label", "variadic", { help = "Group name" })
		parser:add("items", "option", { help = "Comma-separated ids to put in it", required = true })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local label = joinWords(parser:variadics(), "<label>")
		local ids = parseCommaList(getRequired(parser, "items"))

		local made: Item
		local doc = store.transaction(options.dir, function(doc)
			made = graph.makeGroup(doc, label, ids)
		end)

		writeItem(options, doc, made, "Grouped into")
	end,
})
