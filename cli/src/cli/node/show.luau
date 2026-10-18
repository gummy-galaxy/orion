local cli = require("@batteries/cli")
local json = require("@std/json")

local addIdPositional = require("@root/cli/addIdPositional")
local context = require("@root/cli/context")
local getRequired = require("@root/cli/getRequired")
local graph = require("@root/graph")
local loadDoc = require("@root/store/loadDoc")
local render = require("@root/render")
local resolveId = require("@root/query/resolveId")

type Context = context.Context

return table.freeze({
	help = "Show one item or group",
	define = function(parser: cli.Parser)
		addIdPositional(parser, "id")
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local doc = loadDoc(options.dir)
		local item = graph.get(doc, resolveId(doc, getRequired(parser, "id")))

		if options.asJson then
			options.write(json.serialize(render.itemJson(doc, graph.derive(doc, options.now()), item), true))
		else
			options.write(render.show(doc, graph.derive(doc, options.now()), item))
		end
	end,
})
