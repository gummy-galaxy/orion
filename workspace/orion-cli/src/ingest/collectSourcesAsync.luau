local json = require("@std/json")

local adapterTypes = require("@root/adapters/types")
local collectSessionsAsync = require("@root/ingest/collectSessionsAsync")
local getAdapter = require("@root/adapters/getAdapter")
local getUnix = require("@root/adapters/getUnix")
local ingestTypes = require("@root/ingest/types")
local placeRecords = require("@root/ingest/placeRecords")
local types = require("@root/types")

type Adapter = adapterTypes.Adapter
type Doc = types.Doc
type Source = types.Source
type CommandRunner = types.CommandRunner
type Result = ingestTypes.Result

-- Sessions attach to cards that already exist, so agents collect after every
-- source that can add one.
local AGENT_ORDER = math.huge

-- `commands` holds the programs this machine runs for the canvas's sources, by
-- source id.
local function collectSourcesAsync(
	doc: Doc,
	commands: { [string]: { string } },
	run: CommandRunner,
	now: string,
	selected: string?
): { Result }
	local sources: { { source: Source, index: number, order: number } } = {}
	local found = false

	for index, source in doc.settings.sources do
		if selected and source.id ~= selected then
			continue
		end

		found = true
		local succeeded, adapter = pcall(getAdapter, source.kind)
		local verbs = if succeeded then (adapter :: Adapter).source else nil
		local order = if verbs then verbs.collectOrder or 0 elseif succeeded then AGENT_ORDER else 0
		table.insert(sources, { source = source, index = index, order = order })
	end

	assert(found or not selected, `no source with id "{selected}"`)
	table.sort(
		sources,
		function(
			left: { source: Source, index: number, order: number },
			right: { source: Source, index: number, order: number }
		)
			local leftOrder = left.order
			local rightOrder = right.order
			return if leftOrder == rightOrder then left.index < right.index else leftOrder < rightOrder
		end
	)

	local shadow = table.clone(doc)
	shadow.nodes = {}
	shadow.links = table.clone(doc.links)

	for _, item in doc.nodes do
		local copy = table.clone(item)
		copy.data = json.deserialize(json.serialize(item.data)) :: json.Object
		table.insert(shadow.nodes, copy)
	end

	local results: { Result } = {}
	local since = os.date("!%Y-%m-%d", getUnix(now) - 14 * 86400)

	for _, entry in sources do
		local source = entry.source
		local result: Result =
			{ source = source, report = { id = source.id, added = 0, updated = 0, linked = 0 }, order = entry.order }
		local succeeded, failure = pcall(function()
			local adapter = getAdapter(source.kind)
			local context = { now = now, since = since, doc = shadow, commands = commands }
			local records = if adapter.source then adapter.source.collectAsync(source, run, context) else {}

			if adapter.agent then
				local sessions = collectSessionsAsync(source, adapter.agent, run, context)
				table.move(sessions, 1, #sessions, #records + 1, records)
			end

			result.records = records
		end)

		if not succeeded then
			result.report.failed = tostring(failure)
		end

		if result.records then
			placeRecords(shadow, { result })
			result.report.added, result.report.updated, result.report.linked = 0, 0, 0
		end

		table.insert(results, result)
	end

	table.sort(results, function(left, right)
		local leftIndex, rightIndex = 0, 0

		for index, source in doc.settings.sources do
			if source.id == left.source.id then
				leftIndex = index
			end
			if source.id == right.source.id then
				rightIndex = index
			end
		end

		return leftIndex < rightIndex
	end)

	return results
end

return collectSourcesAsync
