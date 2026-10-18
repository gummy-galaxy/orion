local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local createGroup = require("@root/graph/createGroup")
local joinWords = require("@root/cli/joinWords")
local store = require("@root/store")
local types = require("@root/types")
local writeItem = require("@root/cli/writeItem")

type Context = context.Context
type Item = types.Item

return table.freeze({
	help = "Make an empty group, optionally inside another",
	define = function(parser: cli.Parser)
		parser:add("label", "variadic", { help = "Group name" })
		parser:add("in", "option", { help = "Group to make it inside" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local label = joinWords(parser:variadics(), "<label>")

		local made: Item
		local doc = store.transaction(options.dir, function(doc)
			made = createGroup(doc, label, parser:get("in"))
		end)

		writeItem(options, doc, made, "Created group")
	end,
})
