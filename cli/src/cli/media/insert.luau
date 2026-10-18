local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local getLabel = require("@root/graph/getLabel")
local insertFile = require("@root/media/insertFile")

type Context = context.Context

return table.freeze({
	help = "Insert a media node from a file",
	define = function(parser: cli.Parser)
		parser:add("file", "positional", { help = "Media file (PNG, JPEG, GIF, or WebP supported)" })
		parser:add("label", "option", { help = "Node label" })
		parser:add("group", "option", { help = "Group to put the node in" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,
	run = function(parser: cli.Parser, options: Context)
		local item = insertFile(
			options.dir,
			options.workspace,
			assert(parser:get("file"), "file is required"),
			parser:get("label"),
			parser:get("group")
		)
		if parser:has("json") then
			options.write(json.serialize(
				json.object({
					id = item.id,
					label = getLabel(item),
					asset = item.data.asset,
					canvas = options.workspace,
				}),
				true
			))
		else
			options.write(`Inserted image {item.id} · {getLabel(item)}`)
		end
	end,
})
