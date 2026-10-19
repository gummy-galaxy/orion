local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local formatRefreshReport = require("@root/github/formatRefreshReport")
local getAdapter = require("@root/adapters/getAdapter")
local githubTypes = require("@root/github/types")
local loadDoc = require("@root/store/loadDoc")
local runTransaction = require("@root/store/runTransaction")

type Context = context.Context
type RefreshReport = githubTypes.Report

local DEPRECATION = "`orion sync` is deprecated and will be removed. `orion ingest` refreshes pull requests too."

return table.freeze({
	help = "Update pull request items from GitHub (deprecated: use ingest)",
	mcp = { skip = "is deprecated in favor of ingest" },
	define = function(parser: cli.Parser)
		parser:add(
			"discover",
			"flag",
			{ help = "Add your open pull requests that aren't on the canvas to an Inbox group" }
		)
		parser:add("dry-run", "flag", { help = "Show what would change without writing" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local dryRun = parser:has("dry-run")
		local snapshot = loadDoc(options.dir)
		local apply = assert(getAdapter("github").refresh)(
			snapshot,
			options.runner,
			{ discover = parser:has("discover"), now = options.now() }
		)

		local report: RefreshReport

		if dryRun then
			report = apply(snapshot)
		else
			runTransaction(options.dir, function(doc)
				report = apply(doc)
			end)
		end

		if options.asJson then
			options.write(json.serialize(report :: any, true))
		else
			options.write(`{formatRefreshReport(report, dryRun)}\n{DEPRECATION}`)
		end
	end,
})
