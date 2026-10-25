local cli = require("@batteries/cli")

local addArgument = require("@root/cli/addArgument")
local addIdPositional = require("@root/cli/addIdPositional")
local appendEmptyValue = require("@root/cli/appendEmptyValue")
local checkStyleAssets = require("@root/style/checkStyleAssets")
local context = require("@root/cli/context")
local fieldValues = require("@root/fieldValues")
local getItem = require("@root/graph/getItem")
local getItemFields = require("@root/cli/getItemFields")
local getRequired = require("@root/cli/getRequired")
local isGroup = require("@root/graph/isGroup")
local resolveId = require("@root/query/resolveId")
local runTransaction = require("@root/store/runTransaction")
local setFields = require("@root/graph/setFields")
local types = require("@root/types")
local writeItem = require("@root/cli/writeItem")

type Context = context.Context
type Item = types.Item

return table.freeze({
	help = "Change a group's fields",
	mcp = {},
	define = function(parser: cli.Parser)
		addIdPositional(parser, "id")
		parser:add("label", "option", { help = "New label" })
		parser:add("blurb", "option", { help = "Group description" })
		addArgument(parser, "arrange", "option", {
			help = "How reflow arranges a group: auto (default) flows by dependency, custom keeps items where they are",
			type = "enum",
			values = fieldValues.arrangements,
		})
		parser:add(
			"cover",
			"option",
			{ help = "Image asset id for the cover, from orion media add --json (empty to clear)" }
		)
		parser:add(
			"background",
			"option",
			{ help = "Color, color token such as card.background, or image asset id (empty to clear)" }
		)
		parser:add(
			"header",
			"option",
			{ help = "Markdown with layout HTML shown under the group's title (empty to clear)" }
		)
		addArgument(parser, "color", "option", {
			help = "The group's tint: teal, blue, purple, amber, rose, green, or slate (empty to clear)",
			type = "enum",
			values = appendEmptyValue(fieldValues.colors),
		})
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local idInput = getRequired(parser, "id")
		local values = getItemFields(parser)
		checkStyleAssets(options.dir, values.cover)
		checkStyleAssets(options.dir, values.background)

		local changed: Item
		local doc = runTransaction(options.dir, function(current)
			local id = resolveId(current, idInput)
			assert(isGroup(getItem(current, id)), `"{id}" is an item; use orion card set`)
			changed = setFields(current, id, values)
		end)

		writeItem(options, doc, changed, "Updated")
	end,
})
