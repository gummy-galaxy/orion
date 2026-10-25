local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local runTransaction = require("@root/store/runTransaction")
local setSourceCommand = require("@root/sources/setSourceCommand")
local writeResult = require("@root/cli/writeResult")

type Context = context.Context

return table.freeze({
	help = "Remove an ingestion source",
	mcp = { annotations = { destructiveHint = true } },
	define = function(parser: cli.Parser)
		parser:add("id", "positional", { help = "Source id" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local id = assert(parser:get("id"), "missing <id>")
		local doc = runTransaction(options.dir, function(current)
			local found = false

			for index = #current.settings.sources, 1, -1 do
				if current.settings.sources[index].id == id then
					table.remove(current.settings.sources, index)
					found = true
				end
			end

			assert(found, `no source with id "{id}"`)
		end)

		setSourceCommand(options.root, options.workspace, id, nil)
		writeResult(options, json.object({ revision = doc.revision, id = id }), `Removed source {id}`)
	end,
})
