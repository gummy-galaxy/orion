local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local graph = require("@root/graph")
local loadDoc = require("@root/store/loadDoc")

type Context = context.Context

return table.freeze({
	help = "List media nodes",
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,
	run = function(parser: cli.Parser, options: Context)
		local items: json.Array = {}
		local lines: { string } = {}
		for _, item in loadDoc(options.dir).nodes do
			if item.type == "image" then
				table.insert(items, json.object({ id = item.id, label = graph.label(item), asset = item.data.asset }))
				table.insert(lines, `{item.id}  {graph.label(item)}`)
			end
		end
		options.write(
			if parser:has("json")
				then json.serialize(items, true)
				else if #lines > 0 then table.concat(lines, "\n") else "No media."
		)
	end,
})
