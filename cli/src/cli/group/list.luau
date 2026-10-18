local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local derive = require("@root/graph/derive")
local isGroup = require("@root/graph/isGroup")
local loadDoc = require("@root/store/loadDoc")
local renderGroup = require("@root/render/group")

type Context = context.Context

return table.freeze({
	help = "List groups with their progress",
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(_parser: cli.Parser, options: Context)
		local doc = loadDoc(options.dir)
		local derived = derive(doc, options.now())
		local values: json.Array = {}
		local lines = {}

		for _, group in doc.nodes do
			if isGroup(group) then
				table.insert(values, renderGroup.serialize(derived, group))
				table.insert(lines, `{group.id}  {renderGroup.formatLine(derived, group)}`)
			end
		end

		options.write(if options.asJson then json.serialize(values, true) else table.concat(lines, "\n"))
	end,
})
