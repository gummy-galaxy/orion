local batteriesCli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local graph = require("@root/graph")
local render = require("@root/render")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Show the group open in the app and what's selected",
	define = function(parser: batteriesCli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,
	run = function(_parser: batteriesCli.Parser, options: Context)
		local doc = store.load(options.dir)
		local report = store.readFocus(options.dir)
		local derived = graph.derive(doc)
		if options.asJson then
			options.write(json.serialize(render.serializeFocus(doc, derived, report), true))
		else
			options.write(render.formatFocus(doc, derived, report))
		end
	end,
})
