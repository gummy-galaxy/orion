local adapterTypes = require("@root/adapters/types")
local getAdapter = require("@root/adapters/getAdapter")
local getErrorText = require("@root/getErrorText")
local getRefKey = require("@root/adapters/getRefKey")
local importTypes = require("@root/import/types")
local types = require("@root/types")

type Entry = importTypes.Entry
type Source = types.Source
type CommandRunner = types.CommandRunner
type ResolvedRef = types.ResolvedRef

type Pending = { entry: Entry, resolved: ResolvedRef }

local PUBLIC_GITHUB = "github"

local function findSource(sources: { Source }, id: string): Source?
	for _, source in sources do
		if source.id == id then
			return source
		end
	end

	return nil
end

-- A ref's adapter is its source's kind. A GitHub URL for an unconfigured host resolves to the source id "github", which no
-- configured source has, so it belongs to the GitHub adapter.
local function getKind(sources: { Source }, sourceId: string): string
	local source = findSource(sources, sourceId)
	return if source then source.kind else PUBLIC_GITHUB
end

-- Looks up the card for each resolved entry, one adapter call per kind. Sets the record or the error on each entry.
local function lookupRecordsAsync(entries: { Entry }, context: adapterTypes.Context, run: CommandRunner)
	local byKind: { [string]: { Pending } } = {}

	for _, entry in entries do
		local resolved = entry.resolved

		if resolved then
			local kind = getKind(context.doc.settings.sources, resolved.ref.source)
			byKind[kind] = byKind[kind] or {}
			table.insert(byKind[kind], { entry = entry, resolved = resolved })
		end
	end

	for kind, pending in byKind do
		local lookupRefsAsync = getAdapter(kind).lookupRefsAsync

		if not lookupRefsAsync then
			for _, item in pending do
				item.entry.error = `{kind} refs can't be looked up`
			end
			continue
		end

		local refs: { ResolvedRef } = {}
		for _, item in pending do
			table.insert(refs, item.resolved)
		end

		local succeeded, result = pcall(lookupRefsAsync, refs, context, run)

		if not succeeded then
			for _, item in pending do
				item.entry.error = getErrorText(result)
			end
			continue
		end

		for _, item in pending do
			local key = getRefKey(item.resolved.ref)
			item.entry.record = result.records[key]
			item.entry.error = if item.entry.record then nil else result.failures[key] or "not found"
		end
	end
end

return lookupRecordsAsync
