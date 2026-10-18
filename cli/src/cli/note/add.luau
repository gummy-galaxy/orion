local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local graph = require("@root/graph")
local joinWords = require("@root/cli/joinWords")
local resolveOptionalId = require("@root/cli/resolveOptionalId")
local runTransaction = require("@root/store/runTransaction")
local types = require("@root/types")
local writeItem = require("@root/cli/writeItem")

type Context = context.Context
type Item = types.Item

return table.freeze({
	help = "Add a note, optionally between two linked items",
	define = function(parser: cli.Parser)
		parser:add("text", "variadic", { help = "Note text" })
		parser:add("group", "option", { help = "Group to add it to" })
		parser:add("after", "option", { help = "Item the note follows" })
		parser:add("before", "option", { help = "Item the note leads into" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local text = joinWords(parser:variadics(), "<text>")

		local added: Item
		local doc = runTransaction(options.dir, function(doc)
			added = graph.addNote(doc, text, {
				group = resolveOptionalId(doc, parser:get("group")),
				after = resolveOptionalId(doc, parser:get("after")),
				before = resolveOptionalId(doc, parser:get("before")),
			})
		end)

		writeItem(options, doc, added, "Added note")
	end,
})
