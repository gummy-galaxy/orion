local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local getLabel = require("@root/canvas/items/getLabel")
local loadDoc = require("@root/storage/canvases/loadDoc")

type Context = context.Context

return table.freeze({
	help = "List media nodes",
	mcp = { annotations = { readOnlyHint = true } },
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,
	run = function(parser: cli.Parser, options: Context)
		local items: json.Array = {}
		local lines: { string } = {}
		for _, item in loadDoc(options.dir).nodes do
			if item.type == "image" then
				table.insert(items, json.object({ id = item.id, label = getLabel(item), asset = item.data.asset }))
				table.insert(lines, `{item.id}  {getLabel(item)}`)
			end
		end
		options.write(
			if parser:has("json")
				then json.serialize(items, true)
				else if #lines > 0 then table.concat(lines, "\n") else "No media."
		)
	end,
})
