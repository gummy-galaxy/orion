local cli = require("@batteries/cli")
local json = require("@std/json")
local process = require("@std/process")

local addArgument = require("@root/cli/arguments/addArgument")
local appendLog = require("@root/storage/log/appendLog")
local context = require("@root/cli/context")
local createEntry = require("@root/storage/log/createEntry")
local encodeEntry = require("@root/storage/log/encodeEntry")
local formatEntry = require("@root/storage/log/formatEntry")
local parseCommaList = require("@root/cli/arguments/parseCommaList")
local types = require("@root/types")

type Context = context.Context
type LogAuthor = types.LogAuthor

return table.freeze({
	help = "Log what happened, optionally attached to cards. Corrections are new entries.",
	mcp = {},
	define = function(parser: cli.Parser)
		addArgument(parser, "text", "variadic", { help = "What happened", required = true, type = "words" })
		addArgument(
			parser,
			"card",
			"option",
			{ help = "Card ids to attach the entry to, comma-separated", type = "commaList" }
		)
		addArgument(parser, "agent", "option", {
			help = "Log as this agent. Without it, the entry is by you",
			mcp = { required = true, description = "The agent's name, such as claude." },
		})
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local text = table.concat(parser:variadics(), " ")
		local cardOption = parser:get("card")
		local cards = if cardOption then parseCommaList(cardOption) else {}
		local agent = parser:get("agent")

		local author: LogAuthor = if agent
			then { kind = "agent", name = agent }
			else { kind = "person", name = process.env.USER or "person" }
		assert(author.name:match("%S"), "agent name must not be empty")

		local entry = appendLog(options.dir, function(entries, doc)
			return createEntry(entries, doc, {
				text = text,
				author = author,
				cards = cards,
				time = options.now(),
			})
		end)

		if options.asJson then
			options.write(json.serialize(encodeEntry(entry), true))
		else
			options.write(`Logged {entry.id} · {formatEntry(entry, true)}`)
		end
	end,
})
