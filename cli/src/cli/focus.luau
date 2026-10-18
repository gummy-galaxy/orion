local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local graph = require("@root/graph")
local loadDoc = require("@root/store/loadDoc")
local readFocus = require("@root/store/readFocus")
local renderFocus = require("@root/render/focus")

type Context = context.Context

return table.freeze({
	help = "Show the group open in the app and what's selected",
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,
	run = function(_parser: cli.Parser, options: Context)
		local doc = loadDoc(options.dir)
		local report = readFocus(options.dir)
		local derived = graph.derive(doc, options.now())
		if options.asJson then
			options.write(json.serialize(renderFocus.serialize(doc, derived, report), true))
		else
			options.write(renderFocus.format(doc, derived, report))
		end
	end,
})
