local cli = require("@batteries/cli")
local json = require("@std/json")

local applyRepositories = require("@root/github/applyRepositories")
local collectSourcesAsync = require("@root/ingest/collectSourcesAsync")
local context = require("@root/cli/context")
local fetchRepositoriesAsync = require("@root/github/fetchRepositoriesAsync")
local formatRefreshReport = require("@root/github/formatRefreshReport")
local getReportJson = require("@root/ingest/getReportJson")
local healRefKeys = require("@root/github/healRefKeys")
local ingestTypes = require("@root/ingest/types")
local loadDoc = require("@root/store/loadDoc")
local placeRecords = require("@root/ingest/placeRecords")
local readSourceCommands = require("@root/sources/readSourceCommands")
local refreshAdaptersAsync = require("@root/ingest/refreshAdaptersAsync")
local runTransaction = require("@root/store/runTransaction")
local types = require("@root/types")

type Context = context.Context
type Doc = types.Doc

local function getReport(report: ingestTypes.Report, isDryRun: boolean): string
	local lines = { if isDryRun then "Ingest dry run:" else "Ingested:" }

	for _, source in report.sources do
		table.insert(
			lines,
			`{source.id}: {source.added} added, {source.updated} updated, {source.linked} linked{if source.failed
				then `; failed: {source.failed}`
				else ""}`
		)
	end

	for _, refresh in report.refreshes or {} do
		if refresh.failed then
			table.insert(lines, `{refresh.kind} refresh failed: {refresh.failed}`)
		elseif refresh.report then
			table.insert(lines, formatRefreshReport(refresh.report, isDryRun))
		end
	end

	return table.concat(lines, "\n")
end

return table.freeze({
	help = "Import work from configured sources and refresh the cards they track",
	mcp = { annotations = { openWorldHint = true } },
	define = function(parser: cli.Parser)
		parser:add("dry-run", "flag", { help = "Show changes without writing" })
		parser:add("source", "option", { help = "Only ingest this source id" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local isDryRun = parser:has("dry-run")
		local now = options.now()
		local selected = parser:get("source")
		local snapshot = loadDoc(options.dir)
		-- Refs take their repositories' ids and current names before anything matches against them, so a repository that
		-- moved keeps its cards.
		local found = fetchRepositoriesAsync(snapshot, options.runner)
		applyRepositories(snapshot, found, now)
		healRefKeys(snapshot)
		local fetched = collectSourcesAsync(
			snapshot,
			readSourceCommands(options.root, options.workspace),
			options.runner,
			now,
			selected
		)
		local applyRefreshes = refreshAdaptersAsync(snapshot, options.runner, now, selected)
		local report: ingestTypes.Report

		-- Fetching happens above, outside the lock. Refreshing after placing skips the cards this run added when listing
		-- what's unplaced.
		local function apply(doc: Doc)
			applyRepositories(doc, found, now)
			healRefKeys(doc)
			report = placeRecords(doc, fetched)
			report.refreshes = applyRefreshes(doc)
		end

		local doc: Doc

		if isDryRun then
			doc = loadDoc(options.dir)
			apply(doc)
		else
			doc = runTransaction(options.dir, apply)
		end

		if parser:has("json") then
			local value = getReportJson(report)
			value.dryRun = isDryRun
			value.revision = doc.revision
			options.write(json.serialize(value, true))
		else
			options.write(getReport(report, isDryRun))
		end
	end,
})
