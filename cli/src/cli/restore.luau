local cli = require("@batteries/cli")
local fs = require("@std/fs")
local json = require("@std/json")

local context = require("@root/cli/context")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Restore a saved revision as a new revision",
	define = function(parser: cli.Parser)
		parser:add("revision", "positional", { help = "Revision to restore" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local value = assert(parser:get("revision"), "missing <revision>")
		assert(value:match("^%d+$"), "revision must be a nonnegative integer")
		local revision = tonumber(value)
		local restored = store.transaction(options.dir, function(doc)
			local selected: store.Backup?

			for _, backup in store.getBackups(options.dir) do
				if backup.revision == revision then
					selected = backup
					break
				end
			end

			assert(selected, `no backup for revision {revision}`)
			local snapshot = store.decode(fs.readFileToString(selected.file))
			doc.nodes = snapshot.nodes
			doc.links = snapshot.links
			doc.settings = snapshot.settings
			doc.github = snapshot.github
			local raw = doc.raw or json.object({})
			raw.settings = if snapshot.raw then snapshot.raw.settings else nil
			doc.raw = raw
		end)

		options.write(`Restored revision {revision} as revision {restored.revision}`)
	end,
})
