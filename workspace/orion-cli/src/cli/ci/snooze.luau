local cli = require("@batteries/cli")
local json = require("@std/json")

local addArgument = require("@root/cli/addArgument")
local changeCheckSnooze = require("@root/checks/changeCheckSnooze")
local context = require("@root/cli/context")
local parseUntil = require("@root/time/parseUntil")
local runTransaction = require("@root/store/runTransaction")
local writeResult = require("@root/cli/writeResult")

type Context = context.Context

return table.freeze({
	help = "Leave a CI job's failures off every card in a repository until it passes, or until a time",
	mcp = {},
	define = function(parser: cli.Parser)
		parser:add("name", "positional", { help = "The job's name, as GitHub shows it" })
		addArgument(
			parser,
			"repo",
			"option",
			{ help = "Repository the job runs in, as owner/name (required)", mcp = { required = true } }
		)
		parser:add("until", "option", {
			help = "When it ends: an ISO 8601 date or date-time, in local time unless it ends in Z or an offset. "
				.. "Without it, the snooze lasts on each card until the job passes there",
		})
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		local repo = assert(parser:get("repo"), "missing --repo <owner/name>")
		local given = parser:get("until")
		local untilTime = if given then parseUntil(given) else nil
		local now = options.now()
		assert(untilTime == nil or untilTime > now, "--until must be in the future")

		local doc = runTransaction(options.dir, function(current)
			changeCheckSnooze(current, { repo = repo, name = name, snoozed = true, untilTime = untilTime, at = now })
		end)

		local value = json.object({ revision = doc.revision, repo = repo, name = name })
		value["until"] = untilTime
		writeResult(
			options,
			value,
			`Snoozed {name} in {repo} {if untilTime then `until {untilTime}` else "until it passes"}`
		)
	end,
})
