local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local formatEntry = require("@root/log/formatEntry")
local getCardEntries = require("@root/log/getCardEntries")
local graph = require("@root/graph")
local newestFirst = require("@root/log/newestFirst")
local render = require("@root/render")
local store = require("@root/store")

type Context = context.Context

local DEFAULT_LIMIT = 5

return table.freeze({
	help = "Show one card with its most recent log entries",
	define = function(parser: cli.Parser)
		parser:add("id", "positional", { help = "Card id" })
		parser:add("limit", "option", { help = `How many recent entries to show (default {DEFAULT_LIMIT})` })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local id = assert(parser:get("id"), "missing <id>")
		local limit = tonumber(parser:get("limit") or tostring(DEFAULT_LIMIT))
		assert(limit and limit >= 1 and limit % 1 == 0, "limit must be a positive integer")

		local doc = store.load(options.dir)
		local item = graph.get(doc, id)
		assert(not graph.isGroup(item), `"{id}" is a group; use orion group set`)

		local derived = graph.derive(doc)
		local recent = newestFirst(getCardEntries(store.readLog(options.dir), id), limit)

		if options.asJson then
			local value = render.itemJson(doc, derived, item)
			local entries: json.Array = {}

			for _, entry in recent do
				table.insert(entries, store.encodeLogEntry(entry))
			end

			value.log = entries
			options.write(json.serialize(value, true))
			return
		end

		local lines = { render.show(doc, derived, item), "", "Log" }

		for _, entry in recent do
			table.insert(lines, `  {entry.id}  {formatEntry(entry, false)}`)
		end

		if #recent == 0 then
			table.insert(lines, "  No entries yet.")
		end

		options.write(table.concat(lines, "\n"))
	end,
})
