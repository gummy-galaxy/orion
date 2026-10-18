local cli = require("@batteries/cli")

local change = require("@root/suggest/change")
local context = require("@root/cli/context")
local runTransaction = require("@root/store/runTransaction")

type Context = context.Context

return table.freeze({
	help = "Dismiss group suggestions",
	define = function(parser: cli.Parser)
		parser:add("ids", "variadic", { help = "Suggestion ids" })
		parser:add("all", "flag", { help = "Dismiss every suggestion" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local changed: { string } = {}
		runTransaction(options.dir, function(doc)
			changed = change(doc, "dismiss", parser:variadics(), parser:has("all"))
		end)

		options.write(`Dismissed {#changed} suggestions: {table.concat(changed, ", ")}`)
	end,
})
