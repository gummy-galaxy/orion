local cli = require("@batteries/cli")

local addArgument = require("@root/cli/addArgument")
local addNote = require("@root/graph/addNote")
local context = require("@root/cli/context")
local joinWords = require("@root/cli/joinWords")
local noteStyle = require("@root/cli/noteStyle")
local resolveOptionalId = require("@root/cli/resolveOptionalId")
local runTransaction = require("@root/store/runTransaction")
local types = require("@root/types")
local writeItem = require("@root/cli/writeItem")

type Context = context.Context
type Item = types.Item

return table.freeze({
	help = "Add a note, optionally between two linked items",
	mcp = {},
	define = function(parser: cli.Parser)
		addArgument(
			parser,
			"text",
			"variadic",
			{ help = "Note text", type = "words", mcp = { description = `Note text. {noteStyle}` } }
		)
		addArgument(parser, "group", "option", { help = "Group to add it to", type = "id" })
		addArgument(parser, "after", "option", { help = "Item the note follows", type = "id" })
		addArgument(parser, "before", "option", { help = "Item the note leads into", type = "id" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local text = joinWords(parser:variadics(), "<text>")

		local added: Item
		local doc = runTransaction(options.dir, function(doc)
			added = addNote(doc, text, {
				group = resolveOptionalId(doc, parser:get("group")),
				after = resolveOptionalId(doc, parser:get("after")),
				before = resolveOptionalId(doc, parser:get("before")),
			})
		end)

		writeItem(options, doc, added, "Added note")
	end,
})
