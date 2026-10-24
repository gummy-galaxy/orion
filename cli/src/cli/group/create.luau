local cli = require("@batteries/cli")

local addArgument = require("@root/cli/addArgument")
local context = require("@root/cli/context")
local createGroup = require("@root/graph/createGroup")
local joinWords = require("@root/cli/joinWords")
local runTransaction = require("@root/store/runTransaction")
local types = require("@root/types")
local writeItem = require("@root/cli/writeItem")

type Context = context.Context
type Item = types.Item

return table.freeze({
	help = "Make an empty group, optionally inside another",
	mcp = {},
	define = function(parser: cli.Parser)
		addArgument(parser, "label", "variadic", { help = "Group name", type = "words" })
		addArgument(parser, "in", "option", { help = "Group to make it inside", type = "id" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local label = joinWords(parser:variadics(), "<label>")

		local made: Item
		local doc = runTransaction(options.dir, function(current)
			made = createGroup(current, label, parser:get("in"))
		end)

		writeItem(options, doc, made, "Created group")
	end,
})
