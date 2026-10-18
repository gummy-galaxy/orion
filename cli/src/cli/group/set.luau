local cli = require("@batteries/cli")

local addIdPositional = require("@root/cli/addIdPositional")
local checkStyleAssets = require("@root/style/checkStyleAssets")
local context = require("@root/cli/context")
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
	define = function(parser: cli.Parser)
		addIdPositional(parser, "id")
		parser:add("label", "option", { help = "New label" })
		parser:add("blurb", "option", { help = "Group description" })
		parser:add("arrange", "option", {
			help = "How reflow arranges a group: auto (default) flows by dependency, custom keeps items where they are",
		})
		parser:add(
			"cover",
			"option",
			{ help = "Image asset id for the cover, from orion media insert --json (empty to clear)" }
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
		parser:add("color", "option", {
			help = "The group's tint: teal, blue, purple, amber, rose, green, or slate (empty to clear)",
		})
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local idInput = getRequired(parser, "id")
		local values = getItemFields(parser)
		checkStyleAssets(options.dir, values.cover)
		checkStyleAssets(options.dir, values.background)

		local changed: Item
		local doc = runTransaction(options.dir, function(doc)
			local id = resolveId(doc, idInput)
			assert(isGroup(getItem(doc, id)), `"{id}" is an item; use orion card set`)
			changed = setFields(doc, id, values)
		end)

		writeItem(options, doc, changed, "Updated")
	end,
})
