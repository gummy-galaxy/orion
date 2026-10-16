local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local store = require("@root/store")
local suggest = require("@root/suggest")

type Context = context.Context

return table.freeze({
	help = "Apply group suggestions",
	define = function(parser: cli.Parser)
		parser:add("ids", "variadic", { help = "Suggestion ids" })
		parser:add("all", "flag", { help = "Apply every suggestion" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local changed: { string } = {}
		store.transaction(options.dir, function(doc)
			changed = suggest.change(doc, "apply", parser:variadics(), parser:has("all"))
		end)

		options.write(`Applied {#changed} suggestions: {table.concat(changed, ", ")}`)
	end,
})
