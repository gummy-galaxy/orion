local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local graph = require("@root/graph")
local renderGroup = require("@root/render/group")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "List groups with their progress",
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(_parser: cli.Parser, options: Context)
		local doc = store.load(options.dir)
		local derived = graph.derive(doc)
		local values: json.Array = {}
		local lines = {}

		for _, group in doc.nodes do
			if graph.isGroup(group) then
				table.insert(values, renderGroup.serialize(doc, derived, group))
				table.insert(lines, `{group.id}  {renderGroup.formatLine(doc, derived, group)}`)
			end
		end

		options.write(if options.asJson then json.serialize(values, true) else table.concat(lines, "\n"))
	end,
})
