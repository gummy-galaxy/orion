local cli = require("@batteries/cli")

local addArgument = require("@root/cli/addArgument")
local changeCheckSnooze = require("@root/checks/changeCheckSnooze")
local context = require("@root/cli/context")
local runTransaction = require("@root/store/runTransaction")

type Context = context.Context

return table.freeze({
	help = "Count a snoozed CI job's failures on cards again",
	mcp = {},
	define = function(parser: cli.Parser)
		parser:add("name", "positional", { help = "The job's name, as GitHub shows it" })
		addArgument(
			parser,
			"repo",
			"option",
			{ help = "Repository the job runs in, as owner/name (required)", mcp = { required = true } }
		)
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = assert(parser:get("name"), "missing <name>")
		local repo = assert(parser:get("repo"), "missing --repo <owner/name>")

		runTransaction(options.dir, function(doc)
			changeCheckSnooze(doc, { repo = repo, name = name, snoozed = false, at = options.now() })
		end)

		options.write(`Unsnoozed {name} in {repo}`)
	end,
})
