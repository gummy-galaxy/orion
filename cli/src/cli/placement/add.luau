local cli = require("@batteries/cli")

local addIdPositional = require("@root/cli/addIdPositional")
local addPlacement = require("@root/graph/addPlacement")
local context = require("@root/cli/context")
local getRequired = require("@root/cli/getRequired")
local resolveId = require("@root/query/resolveId")
local resolveOptionalId = require("@root/cli/resolveOptionalId")
local runTransaction = require("@root/store/runTransaction")

type Context = context.Context

return table.freeze({
	help = "Show a card in one more group. Every copy edits the same card, and links join the card",
	mcp = { skip = "is a #122 spike; the real build decides how tools place cards" },
	define = function(parser: cli.Parser)
		addIdPositional(parser, "id")
		parser:add("group", "option", { help = "Group to show the card in; the top level when absent" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local id: string
		local placementId: string
		local group: string?

		runTransaction(options.dir, function(doc)
			id = resolveId(doc, getRequired(parser, "id"))
			group = resolveOptionalId(doc, parser:get("group"))
			placementId = addPlacement(doc, id, group).id
		end)

		options.write(`Placed {id} in {group or "the top level"} as {placementId}`)
	end,
})
