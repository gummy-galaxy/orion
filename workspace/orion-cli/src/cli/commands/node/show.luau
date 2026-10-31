local cli = require("@batteries/cli")
local json = require("@std/json")

local addIdPositional = require("@root/cli/arguments/addIdPositional")
local context = require("@root/cli/context")
local derive = require("@root/canvas/derive")
local getItem = require("@root/canvas/items/getItem")
local getRequired = require("@root/cli/arguments/getRequired")
local loadDoc = require("@root/storage/canvases/loadDoc")
local render = require("@root/canvas/render")
local resolveId = require("@root/canvas/query/resolveId")

type Context = context.Context

return table.freeze({
	help = "Show one item or group",
	mcp = { annotations = { readOnlyHint = true } },
	define = function(parser: cli.Parser)
		addIdPositional(parser, "id")
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local doc = loadDoc(options.dir)
		local item = getItem(doc, resolveId(doc, getRequired(parser, "id")))

		if options.asJson then
			options.write(json.serialize(render.itemJson(doc, derive(doc, options.now()), item), true))
		else
			options.write(render.show(doc, derive(doc, options.now()), item))
		end
	end,
})
