local cli = require("@batteries/cli")
local json = require("@std/json")

local addArgument = require("@root/cli/addArgument")
local context = require("@root/cli/context")
local getLabel = require("@root/graph/getLabel")
local insertFile = require("@root/media/insertFile")

type Context = context.Context

return table.freeze({
	help = "Insert a media node from a file",
	mcp = {},
	define = function(parser: cli.Parser)
		addArgument(parser, "file", "positional", {
			help = "Media file (PNG, JPEG, GIF, or WebP supported)",
			mcp = {
				description = "Absolute path to a local PNG, JPEG, GIF, or WebP file, which is copied into the canvas.",
			},
		})
		parser:add("label", "option", { help = "Node label" })
		addArgument(parser, "group", "option", { help = "Group to put the node in", type = "id" })
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
