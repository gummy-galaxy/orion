local adapterTypes = require("@root/adapters/types")
local getErrorText = require("@root/getErrorText")
local getRefKey = require("@root/adapters/getRefKey")
local jiraCollectAsync = require("@root/adapters/jira/collectAsync")
local types = require("@root/types")

type LookupResult = adapterTypes.LookupResult
type Record = adapterTypes.Record
type ResolvedRef = types.ResolvedRef
type Source = types.Source
type CommandRunner = types.CommandRunner

local function findSource(sources: { Source }, id: string): Source?
	for _, source in sources do
		if source.id == id then
			return source
		end
	end

	return nil
end

-- Jira keys can only be read through a source's command, so each source runs once and its results are matched by key.
-- A ref outside what the command returns is reported as not found.
local function lookupRefsAsync(refs: { ResolvedRef }, context: adapterTypes.Context, run: CommandRunner): LookupResult
	local result: LookupResult = { records = {}, failures = {} }
	local bySource: { [string]: { ResolvedRef } } = {}

	for _, resolved in refs do
		local sourceId = resolved.ref.source
		bySource[sourceId] = bySource[sourceId] or {}
		table.insert(bySource[sourceId], resolved)
	end

	for sourceId, sourceRefs in bySource do
		local source = assert(findSource(context.doc.settings.sources, sourceId), `no source with id "{sourceId}"`)
		local succeeded, collected = pcall(jiraCollectAsync, source, run, context)

		if not succeeded then
			for _, resolved in sourceRefs do
				result.failures[getRefKey(resolved.ref)] = `could not read {sourceId}: {getErrorText(collected)}`
			end
			continue
		end

		local byKey: { [string]: Record } = {}
		for _, record in collected :: { Record } do
			byKey[getRefKey(record.ref)] = record
		end

		for _, resolved in sourceRefs do
			local key = getRefKey(resolved.ref)
			local record = byKey[key]

			if record then
				result.records[key] = record
			else
				result.failures[key] = `not in the {sourceId} source's results`
			end
		end
	end

	return result
end

return lookupRefsAsync
