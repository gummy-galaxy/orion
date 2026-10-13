local cli = require("@batteries/cli")
local json = require("@std/json")
local process = require("@std/process")

local context = require("@root/cli/context")
local createEntry = require("@root/log/createEntry")
local formatEntry = require("@root/log/formatEntry")
local parseCommaList = require("@root/cli/parseCommaList")
local store = require("@root/store")
local types = require("@root/types")

type Context = context.Context
type LogAuthor = types.LogAuthor

return table.freeze({
	help = "Log what happened, optionally attached to cards. Corrections are new entries.",
	define = function(parser: cli.Parser)
		parser:add("text", "variadic", { help = "What happened", required = true })
		parser:add("card", "option", { help = "Card ids to attach the entry to, comma-separated" })
		parser:add("agent", "option", { help = "Log as this agent. Without it, the entry is by you" })
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

		local entry = store.appendLog(options.dir, function(entries, doc)
			return createEntry(entries, doc, {
				text = text,
				author = author,
				cards = cards,
				time = options.now(),
			})
		end)

		if options.asJson then
			options.write(json.serialize(store.encodeLogEntry(entry), true))
		else
			options.write(`Logged {entry.id} · {formatEntry(entry, true)}`)
		end
	end,
})
