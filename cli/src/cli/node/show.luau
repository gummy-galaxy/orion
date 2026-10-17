local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local getRequired = require("@root/cli/getRequired")
local graph = require("@root/graph")
local render = require("@root/render")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Show one item or group",
	define = function(parser: cli.Parser)
		parser:add("id", "positional", { help = "Item or group id" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local doc = store.load(options.dir)
		local item = graph.get(doc, getRequired(parser, "id"))

		if options.asJson then
			options.write(json.serialize(render.itemJson(doc, graph.derive(doc), item), true))
		else
			options.write(render.show(doc, graph.derive(doc), item))
		end
	end,
})
