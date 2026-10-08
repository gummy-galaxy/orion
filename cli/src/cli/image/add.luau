local batteriesCli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local graph = require("@root/graph")
local images = require("@root/images")

type Context = context.Context

return table.freeze({
	help = "Add an image node from a file",
	define = function(parser: batteriesCli.Parser)
		parser:add("file", "positional", { help = "PNG, JPEG, GIF, or WebP file" })
		parser:add("label", "option", { help = "Image label" })
		parser:add("group", "option", { help = "Group to put the image in" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,
	run = function(parser: batteriesCli.Parser, options: Context)
		local item = images.add(
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
					label = graph.label(item),
					asset = item.data.asset,
					workspace = options.workspace,
				}),
				true
			))
		else
			options.write(`Added image {item.id} · {graph.label(item)}`)
		end
	end,
})
