local cli = require("@batteries/cli")
local json = require("@std/json")

local addIdPositional = require("@root/cli/addIdPositional")
local context = require("@root/cli/context")
local derive = require("@root/graph/derive")
local getItem = require("@root/graph/getItem")
local getRequired = require("@root/cli/getRequired")
local render = require("@root/render")
local resolveId = require("@root/query/resolveId")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Show one item or group",
	define = function(parser: cli.Parser)
		addIdPositional(parser, "id")
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local doc = store.load(options.dir)
		local item = getItem(doc, resolveId(doc, getRequired(parser, "id")))

		if options.asJson then
			options.write(json.serialize(render.itemJson(doc, derive(doc, options.now()), item), true))
		else
			options.write(render.show(doc, derive(doc, options.now()), item))
		end
	end,
})
