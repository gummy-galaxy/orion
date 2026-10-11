local json = require("@std/json")

local ingestTypes = require("@root/ingest/types")

type Report = ingestTypes.Report

local function getReportJson(report: Report): json.Object
	local entries: json.Array = {}

	for _, source in report.sources do
		local entry =
			json.object({ id = source.id, added = source.added, updated = source.updated, linked = source.linked })
		entry.failed = source.failed
		table.insert(entries, entry)
	end

	return json.object({ sources = entries })
end

return getReportJson
