local cli = require("@batteries/cli")
local json = require("@std/json")

local changeCheckSnooze = require("@root/checks/changeCheckSnooze")
local context = require("@root/cli/context")
local runTransaction = require("@root/store/runTransaction")
local writeResult = require("@root/cli/writeResult")

type Context = context.Context

return table.freeze({
	help = "Count a snoozed CI job's failures on cards again",
	define = function(parser: cli.Parser)
		parser:add("name", "positional", { help = "The job's name, as GitHub shows it" })
		parser:add("repo", "option", { help = "Repository the job runs in, as owner/name (required)" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		local repo = assert(parser:get("repo"), "missing --repo <owner/name>")

		local doc = runTransaction(options.dir, function(current)
			changeCheckSnooze(current, { repo = repo, name = name, snoozed = false, at = options.now() })
		end)

		writeResult(
			options,
			json.object({ revision = doc.revision, repo = repo, name = name }),
			`Unsnoozed {name} in {repo}`
		)
	end,
})
