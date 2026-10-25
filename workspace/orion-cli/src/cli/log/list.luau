local cli = require("@batteries/cli")
local json = require("@std/json")

local addArgument = require("@root/cli/addArgument")
local context = require("@root/cli/context")
local encodeEntry = require("@root/log/encodeEntry")
local formatEntry = require("@root/log/formatEntry")
local getCardEntries = require("@root/log/getCardEntries")
local newestFirst = require("@root/log/newestFirst")
local parseLimit = require("@root/cli/parseLimit")
local readLog = require("@root/log/readLog")

type Context = context.Context

return table.freeze({
	help = "List the canvas log, newest first",
	mcp = { annotations = { readOnlyHint = true } },
	define = function(parser: cli.Parser)
		addArgument(parser, "card", "option", { help = "Only entries attached to this card", type = "id" })
		addArgument(
			parser,
			"limit",
			"option",
			{ help = "Show at most this many of the newest entries", type = "integer" }
		)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local limit = parseLimit(parser:get("limit"))
		local entries = readLog(options.dir)
		local card = parser:get("card")

		if card then
			entries = getCardEntries(entries, card)
		end

		local ordered = newestFirst(entries, limit)

		if options.asJson then
			local values: json.Array = {}

			for _, entry in ordered do
				table.insert(values, encodeEntry(entry))
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
