local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local ingest = require("@root/ingest")
local store = require("@root/store")

type Context = context.Context

local function getReport(report: ingest.Report, isDryRun: boolean): string
	local lines = { if isDryRun then "Ingest dry run:" else "Ingested:" }

	for _, source in report.sources do
		table.insert(
			lines,
			`{source.id}: {source.added} added, {source.updated} updated, {source.linked} linked{if source.failed
				then `; failed: {source.failed}`
				else ""}`
		)
	end

	return table.concat(lines, "\n")
end

return table.freeze({
	help = "Import work from configured sources",
	define = function(parser: cli.Parser)
		parser:add("dry-run", "flag", { help = "Show changes without writing" })
		parser:add("source", "option", { help = "Only ingest this source id" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local isDryRun = parser:has("dry-run")
		local now = options.now()
		local fetched = ingest.collect(store.load(options.dir), options.runner, now, parser:get("source"))
		local report: ingest.Report

		if isDryRun then
			report = ingest.apply(store.load(options.dir), fetched, now)
		else
			store.transaction(options.dir, function(doc)
				report = ingest.apply(doc, fetched, now)
			end)
		end

		options.write(
			if parser:has("json")
				then json.serialize(ingest.getReportJson(report), true)
				else getReport(report, isDryRun)
		)
	end,
})
