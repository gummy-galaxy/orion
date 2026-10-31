local cli = require("@batteries/cli")
local fs = require("@std/fs")
local json = require("@std/json")

local addArgument = require("@root/cli/arguments/addArgument")
local context = require("@root/cli/context")
local getInputs = require("@root/sources/import/getInputs")
local importRefsAsync = require("@root/sources/import/importRefsAsync")
local importTypes = require("@root/sources/import/types")
local pad = require("@root/common/text/pad")
local readSourceCommands = require("@root/sources/readSourceCommands")
local requestedRevision = require("@root/cli/arguments/requestedRevision")

type Context = context.Context
type Outcome = importTypes.Outcome
type Report = importTypes.Report

local STATUS_WIDTH = 10

local function countOutcomes(report: Report): (number, number, number)
	local added, existing, failed = 0, 0, 0

	for _, outcome in report.outcomes do
		if outcome.status == "added" then
			added += 1
		elseif outcome.status == "existing" then
			existing += 1
		else
			failed += 1
		end
	end

	return added, existing, failed
end

local function getSummary(report: Report, added: number, existing: number, failed: number): string
	local noun = if added == 1 then "card" else "cards"
	local parts = { `{if report.dryRun then "Would add" else "Added"} {added} {noun}` }

	if existing > 0 then
		table.insert(parts, `{existing} already on the canvas`)
	end

	if failed > 0 then
		table.insert(parts, `{failed} failed`)
	end

	local revision = if report.revision == report.baseRevision
		then `at revision {report.baseRevision}`
		else `at revision {report.baseRevision} → {report.revision}`
	return `{table.concat(parts, ", ")} {revision}`
end

local function getText(report: Report, added: number, existing: number, failed: number): string
	local lines = { getSummary(report, added, existing, failed) }

	for _, outcome in report.outcomes do
		if outcome.status == "failed" then
			table.insert(lines, `  {pad("failed", STATUS_WIDTH)}{outcome.input}: {outcome.error}`)
		else
			local status = if outcome.status == "added" and report.dryRun then "would add" else outcome.status
			table.insert(lines, `  {pad(status, STATUS_WIDTH)}{pad(outcome.id or "", 38)}{outcome.label or ""}`)
		end
	end

	return table.concat(lines, "\n")
end

local function getJson(report: Report, added: number, existing: number, failed: number): string
	local items: json.Array = {}

	for _, outcome in report.outcomes do
		table.insert(
			items,
			json.object({
				input = outcome.input,
				status = outcome.status,
				id = outcome.id,
				label = outcome.label,
				error = outcome.error,
			})
		)
	end

	return json.serialize(
		json.object({
			action = "import",
			dryRun = report.dryRun,
			baseRevision = report.baseRevision,
			revision = report.revision,
			added = added,
			existing = existing,
			failed = failed,
			items = items,
		}),
		true
	)
end

return table.freeze({
	help = "Add a card for each URL or source:key in one step",
	mcp = {
		annotations = { openWorldHint = true },
		omit = {
			{
				option = "stdin",
				reason = "reads refs from stdin, which a tool call can't pipe; the tool takes them as a list",
			},
		},
	},
	define = function(parser: cli.Parser)
		addArgument(
			parser,
			"refs",
			"variadic",
			{ help = "GitHub or Jira URLs, or source:key such as jira:ABC-1", mcp = { required = true } }
		)
		parser:add("stdin", "flag", { help = "Also read one reference per line from stdin" })
		addArgument(parser, "group", "option", { help = "Group to add the cards to", type = "id" })
		parser:add("dry-run", "flag", { help = "Preview the cards without writing" })
		addArgument(parser, "if-revision", "option", {
			help = "Write only if the document has this revision",
			type = "integer",
			minimum = 0,
		})
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local stdin = if parser:has("stdin") then fs.readFileToString("/dev/stdin") else nil
		local inputs = getInputs(parser:variadics(), stdin)
		assert(#inputs > 0, "import needs at least one URL or source:key, as arguments or on stdin with --stdin")

		local report = importRefsAsync(inputs, {
			dir = options.dir,
			groupId = parser:get("group"),
			dryRun = parser:has("dry-run"),
			ifRevision = requestedRevision(parser),
			now = options.now(),
			runner = options.runner,
			commands = readSourceCommands(options.root, options.workspace),
		})
		local added, existing, failed = countOutcomes(report)

		options.write(
			if parser:has("json")
				then getJson(report, added, existing, failed)
				else getText(report, added, existing, failed)
		)

		-- Written first so the outcomes of the refs that did resolve are still
		-- shown; the error sets the exit status.
		if failed > 0 then
			error(`{failed} of {#inputs} refs could not be imported`, 0)
		end
	end,
})
