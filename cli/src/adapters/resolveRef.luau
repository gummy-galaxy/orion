local getAdapter = require("@root/adapters/getAdapter")
local types = require("@root/types")

type ResolvedRef = types.ResolvedRef
type Source = types.Source

-- Kinds whose adapters recognize pasted URLs, tried in this order.
local URL_KINDS = { "github", "jira" }

local function findSource(sources: { Source }, id: string): Source?
	for _, source in sources do
		if source.id == id then
			return source
		end
	end

	return nil
end

-- Turns the value of --ref into a ref. A URL goes to whichever adapter recognizes it; source:key
-- goes to the configured source with that id, which its adapter parses.
local function resolveRef(input: string, sources: { Source }): ResolvedRef
	assert(input ~= "", "--ref needs a URL or source:key")

	if input:match("^https?://") then
		for _, kind in URL_KINDS do
			local refFromUrl = getAdapter(kind).refFromUrl

			if refFromUrl then
				local resolved = refFromUrl(input, sources)

				if resolved then
					return resolved
				end
			end
		end

		error(`no source recognizes {input}; add its GitHub or Jira source first, or use source:key`, 0)
	end

	local sourceId, key = input:match("^([a-z][a-z0-9%-]*):(.+)$")
	if not sourceId or not key then
		error(`--ref takes a URL or source:key, such as jira:ABC-1, not "{input}"`, 0)
	end

	local source = assert(findSource(sources, sourceId), `no source with id "{sourceId}"`)
	local refFromKey = getAdapter(source.kind).refFromKey
	assert(refFromKey, `{source.kind} sources can't attach refs with source:key; use a URL`)

	local ref = assert(refFromKey(key, source), `"{key}" is not a valid {source.kind} key`)

	return ref
end

return resolveRef
