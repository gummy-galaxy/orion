local batteriesCli = require("@batteries/cli")

local context = require("@root/cli/context")
local store = require("@root/store")
local suggest = require("@root/suggest")

type Context = context.Context

return table.freeze({
	help = "Dismiss group suggestions",
	define = function(parser: batteriesCli.Parser)
		parser:add("ids", "variadic", { help = "Suggestion ids" })
		parser:add("all", "flag", { help = "Dismiss every suggestion" })
	end,
	run = function(parser: batteriesCli.Parser, options: Context)
		local changed: { string } = {}
		store.transaction(options.dir, function(doc)
			changed = suggest.change(doc, "dismiss", parser:variadics(), parser:has("all"))
		end)
		options.write(`Dismissed {#changed} suggestions: {table.concat(changed, ", ")}`)
	end,
})
