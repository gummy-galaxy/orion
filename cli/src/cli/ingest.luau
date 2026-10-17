local cli = require("@batteries/cli")
local json = require("@std/json")

local collectSources = require("@root/ingest/collectSources")
local context = require("@root/cli/context")
local formatRefreshReport = require("@root/github/formatRefreshReport")
local getReportJson = require("@root/ingest/getReportJson")
local ingestTypes = require("@root/ingest/types")
local placeRecords = require("@root/ingest/placeRecords")
local refreshAdapters = require("@root/ingest/refreshAdapters")
local store = require("@root/store")
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
	define = function(parser: cli.Parser)
		parser:add("dry-run", "flag", { help = "Show changes without writing" })
		parser:add("source", "option", { help = "Only ingest this source id" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local isDryRun = parser:has("dry-run")
		local now = options.now()
		local selected = parser:get("source")
		local snapshot = store.load(options.dir)
		local fetched = collectSources(snapshot, options.runner, now, selected)
		local applyRefreshes = refreshAdapters(snapshot, options.runner, now, selected)
		local report: ingestTypes.Report

		-- Fetching happens above, outside the lock. Refreshing after placing skips the cards this run added when listing
		-- what's unplaced.
		local function apply(doc: Doc)
			report = placeRecords(doc, fetched)
			report.refreshes = applyRefreshes(doc)
		end

		if isDryRun then
			apply(store.load(options.dir))
		else
			store.transaction(options.dir, apply)
		end

		options.write(
			if parser:has("json") then json.serialize(getReportJson(report), true) else getReport(report, isDryRun)
		)
	end,
})
