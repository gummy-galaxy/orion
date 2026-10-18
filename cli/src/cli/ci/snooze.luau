local cli = require("@batteries/cli")

local changeCheckSnooze = require("@root/checks/changeCheckSnooze")
local context = require("@root/cli/context")
local normalizeUntil = require("@root/checks/normalizeUntil")
local runTransaction = require("@root/store/runTransaction")

type Context = context.Context

return table.freeze({
	help = "Leave a CI job's failures off every card in a repository until it passes, or until a time",
	define = function(parser: cli.Parser)
		parser:add("name", "positional", { help = "The job's name, as GitHub shows it" })
		parser:add("repo", "option", { help = "Repository the job runs in, as owner/name (required)" })
		parser:add("until", "option", {
			help = "End the snooze at a UTC time such as 2026-10-14T18:00:00Z, or a date. Without it, the snooze lasts on each card until the job passes there",
		})
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		local repo = assert(parser:get("repo"), "missing --repo <owner/name>")
		local given = parser:get("until")
		local untilTime = if given then normalizeUntil(given) else nil
		local now = options.now()
		assert(untilTime == nil or untilTime > now, "--until must be in the future")

		runTransaction(options.dir, function(doc)
			changeCheckSnooze(doc, { repo = repo, name = name, snoozed = true, untilTime = untilTime, at = now })
		end)

		options.write(`Snoozed {name} in {repo} {if untilTime then `until {untilTime}` else "until it passes"}`)
	end,
})
