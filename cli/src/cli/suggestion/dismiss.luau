local cli = require("@batteries/cli")
local json = require("@std/json")

local change = require("@root/suggest/change")
local context = require("@root/cli/context")
local runTransaction = require("@root/store/runTransaction")
local writeResult = require("@root/cli/writeResult")

type Context = context.Context

return table.freeze({
	help = "Dismiss group suggestions",
	mcp = {},
	define = function(parser: cli.Parser)
		parser:add("ids", "variadic", { help = "Suggestion ids" })
		parser:add("all", "flag", { help = "Dismiss every suggestion" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local changed: { string } = {}
		local doc = runTransaction(options.dir, function(current)
			changed = change(current, "dismiss", parser:variadics(), parser:has("all"))
		end)

		writeResult(
			options,
			json.object({ revision = doc.revision, ids = changed }),
			`Dismissed {#changed} suggestions: {table.concat(changed, ", ")}`
		)
	end,
})
