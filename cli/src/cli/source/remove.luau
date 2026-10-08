local batteriesCli = require("@batteries/cli")

local context = require("@root/cli/context")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Remove an ingestion source",
	define = function(parser: batteriesCli.Parser)
		parser:add("id", "positional", { help = "Source id" })
	end,

	run = function(parser: batteriesCli.Parser, options: Context)
		local id = assert(parser:get("id"), "missing <id>")
		store.transaction(options.dir, function(doc)
			local found = false

			for index = #doc.settings.sources, 1, -1 do
				if doc.settings.sources[index].id == id then
					table.remove(doc.settings.sources, index)
					found = true
				end
			end

			assert(found, `no source with id "{id}"`)
		end)

		options.write(`Removed source {id}`)
	end,
})
