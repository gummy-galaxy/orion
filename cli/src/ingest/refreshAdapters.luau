local getAdapter = require("@root/adapters/getAdapter")
local getRefs = require("@root/refs/getRefs")
local ingestTypes = require("@root/ingest/types")
local types = require("@root/types")

type Doc = types.Doc
type CommandRunner = types.CommandRunner
type RefreshReport = ingestTypes.RefreshReport

-- The source kinds the workspace uses: those of its sources, and those its cards' refs came from.
local function getKinds(doc: Doc): { string }
	local kindOf: { [string]: string } = {}
	local seen: { [string]: boolean } = {}

	for _, source in doc.settings.sources do
		kindOf[source.id] = source.kind
		seen[source.kind] = true
	end

	for _, item in doc.nodes do
		for _, ref in getRefs(item) do
			seen[kindOf[ref.source] or ref.source] = true
		end
	end

	local kinds = {}

	for kind in seen do
		table.insert(kinds, kind)
	end

	table.sort(kinds)

	return kinds
end

--[[
	Runs the refresh of each adapter the workspace uses, which updates cards already on the canvas, such as GitHub's
	pull request states. With `selected`, only that source's kind refreshes. A failed refresh is reported rather than
	raised, as a failed source is.
]]
local function refreshAdapters(doc: Doc, run: CommandRunner, now: string, selected: string?): { RefreshReport }
	local kinds = getKinds(doc)

	if selected then
		kinds = {}

		for _, source in doc.settings.sources do
			if source.id == selected then
				kinds = { source.kind }
			end
		end
	end

	local reports: { RefreshReport } = {}

	for _, kind in kinds do
		local succeeded, adapter = pcall(getAdapter, kind)

		if not succeeded or not adapter.refresh then
			continue
		end

		local refresh = adapter.refresh
		local entry: RefreshReport = { kind = kind }
		local didRefresh, failure = pcall(function()
			entry.report = refresh(doc, run, { discover = false, now = now })
		end)

		if not didRefresh then
			entry.failed = tostring(failure)
		end

		table.insert(reports, entry)
	end

	return reports
end

return refreshAdapters
