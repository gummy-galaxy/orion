local cli = require("@batteries/cli")
local json = require("@std/json")

local addIdPositional = require("@root/cli/addIdPositional")
local context = require("@root/cli/context")
local getPlacements = require("@root/graph/getPlacements")
local getRequired = require("@root/cli/getRequired")
local loadDoc = require("@root/store/loadDoc")
local resolveId = require("@root/query/resolveId")

type Context = context.Context

return table.freeze({
	help = "List every place a card appears, its own first",
	mcp = { skip = "is a #122 spike; the real build decides how tools place cards" },
	define = function(parser: cli.Parser)
		addIdPositional(parser, "id")
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local doc = loadDoc(options.dir)
		local placements = getPlacements(doc, resolveId(doc, getRequired(parser, "id")))

		if options.asJson then
			local values: json.Array = {}

			for _, placement in placements do
				local value = json.object({ id = placement.id, node = placement.node })
				value.group = placement.parentId
				table.insert(values, value)
			end

			options.write(json.serialize(values, true))
			return
		end

		local lines: { string } = {}

		for _, placement in placements do
			table.insert(lines, `{placement.id}\t{placement.parentId or "(top level)"}`)
		end

		options.write(table.concat(lines, "\n"))
	end,
})
