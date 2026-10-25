local getAdapter = require("@root/adapters/getAdapter")
local getRefs = require("@root/refs/getRefs")
local githubTypes = require("@root/github/types")
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
	Fetches the refresh of each adapter the workspace uses, which updates cards already on the canvas, such as GitHub's
	pull request states, and returns the step that applies them. It reads `doc` without changing it, so callers can
	fetch outside the workspace lock and apply under it. With `selected`, only that source's kind refreshes. A failed
	refresh is reported rather than raised, as a failed source is.
]]
local function refreshAdapters(doc: Doc, run: CommandRunner, now: string, selected: string?): (Doc) -> { RefreshReport }
	local kinds = getKinds(doc)

	if selected then
		kinds = {}

		for _, source in doc.settings.sources do
			if source.id == selected then
				kinds = { source.kind }
			end
		end
	end

	local pending: { { kind: string, apply: ((Doc) -> githubTypes.Report)?, failed: string? } } = {}

	for _, kind in kinds do
		local succeeded, adapter = pcall(getAdapter, kind)

		if not succeeded or not adapter.refresh then
			continue
		end

		local didFetch, result = pcall(adapter.refresh, doc, run, { now = now })
		table.insert(pending, {
			kind = kind,
			apply = if didFetch then result else nil,
			failed = if didFetch then nil else tostring(result),
		})
	end

	return function(current: Doc): { RefreshReport }
		local reports: { RefreshReport } = {}

		for _, entry in pending do
			local report: RefreshReport = { kind = entry.kind, failed = entry.failed }
			local apply = entry.apply

			if apply then
				local didApply, result = pcall(apply, current)

				if didApply then
					report.report = result
				else
					report.failed = tostring(result)
				end
			end

			table.insert(reports, report)
		end

		return reports
	end
end

return refreshAdapters
