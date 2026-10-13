local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local formatEntry = require("@root/log/formatEntry")
local getCardEntries = require("@root/log/getCardEntries")
local newestFirst = require("@root/log/newestFirst")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "List the canvas log, newest first",
	define = function(parser: cli.Parser)
		parser:add("card", "option", { help = "Only entries attached to this card" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local entries = store.readLog(options.dir)
		local card = parser:get("card")

		if card then
			entries = getCardEntries(entries, card)
		end

		local ordered = newestFirst(entries)

		if options.asJson then
			local values: json.Array = {}

			for _, entry in ordered do
				table.insert(values, store.encodeLogEntry(entry))
			end

			options.write(json.serialize(values, true))
			return
		end

		local lines: { string } = {}

		for _, entry in ordered do
			table.insert(lines, `{entry.id}  {formatEntry(entry, true)}`)
		end

		options.write(if #lines > 0 then table.concat(lines, "\n") else "No log entries.")
	end,
})
