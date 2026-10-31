local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local derive = require("@root/canvas/derive")
local loadDoc = require("@root/storage/canvases/loadDoc")
local readFocus = require("@root/storage/focus/readFocus")
local renderFocus = require("@root/canvas/render/focus")

type Context = context.Context

return table.freeze({
	help = "Show the group open in the app and what's selected",
	mcp = { annotations = { readOnlyHint = true } },
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,
	run = function(_parser: cli.Parser, options: Context)
		local doc = loadDoc(options.dir)
		local report = readFocus(options.dir)
		local derived = derive(doc, options.now())
		if options.asJson then
			options.write(json.serialize(renderFocus.serialize(doc, derived, report), true))
		else
			options.write(renderFocus.format(doc, derived, report))
		end
	end,
})
