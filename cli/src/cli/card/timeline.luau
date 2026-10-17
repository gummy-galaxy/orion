local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local encodeEntry = require("@root/log/encodeEntry")
local formatEntry = require("@root/log/formatEntry")
local getCardEntries = require("@root/log/getCardEntries")
local graph = require("@root/graph")
local newestFirst = require("@root/log/newestFirst")
local parseLimit = require("@root/cli/parseLimit")
local readLog = require("@root/log/readLog")
local store = require("@root/store")

type Context = context.Context

local DEFAULT_LIMIT = 5

return table.freeze({
	help = "Show a card's timeline: its most recent log entries, newest first",
	define = function(parser: cli.Parser)
		parser:add("id", "positional", { help = "Card id" })
		parser:add("limit", "option", { help = `How many recent entries to show (default {DEFAULT_LIMIT})` })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local id = assert(parser:get("id"), "missing <id>")
		local limit = parseLimit(parser:get("limit")) or DEFAULT_LIMIT

		local item = graph.get(store.load(options.dir), id)
		assert(not graph.isGroup(item), `"{id}" is a group; only cards have a timeline`)

		local recent = newestFirst(getCardEntries(readLog(options.dir), id), limit)

		if options.asJson then
			local values: json.Array = {}

			for _, entry in recent do
				table.insert(values, encodeEntry(entry))
			end

			options.write(json.serialize(values, true))
			return
		end

		local lines: { string } = {}

		for _, entry in recent do
			table.insert(lines, `{entry.id}  {formatEntry(entry, false)}`)
		end

		options.write(if #lines > 0 then table.concat(lines, "\n") else "No entries yet.")
	end,
})
