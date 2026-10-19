local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local runTransaction = require("@root/store/runTransaction")

type Context = context.Context

return table.freeze({
	help = "Remove an ingestion source",
	mcp = { skip = "changes which sources ingest reads, so it stays with source add" },
	define = function(parser: cli.Parser)
		parser:add("id", "positional", { help = "Source id" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local id = assert(parser:get("id"), "missing <id>")
		runTransaction(options.dir, function(doc)
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
