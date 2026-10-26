local getAdapter = require("@root/adapters/getAdapter")
local getGithubKey = require("@root/refs/getGithubKey")
local types = require("@root/types")

type ResolvedRef = types.ResolvedRef
type Source = types.Source

-- Kinds whose adapters recognize pasted URLs, tried in this order.
local URL_KINDS = { "github", "jira" }
-- Reserved for branch:owner/name@branch, so no configured source may take this
-- id.
local BRANCH_PREFIX = "branch"
local NAME_PATTERN = "^[%w_.%-]+$"

local function findSource(sources: { Source }, id: string): Source?
	for _, source in sources do
		if source.id == id then
			return source
		end
	end

	return nil
end

-- A branch ref has the key hop records for its branches: owner/name@branch,
-- with the host in front on GitHub Enterprise. The first @ splits it, because
-- repositories never contain one.
local function refFromBranch(input: string, sources: { Source }): ResolvedRef
	local location, branch = input:match("^([^@]+)@(%S+)$")
	assert(location and branch, `branch: takes owner/name@branch, not "{input}"`)

	local host, owner, name = location:match("^([^/]+)/([^/]+)/([^/]+)$")
	if not host then
		owner, name = location:match("^([^/]+)/([^/]+)$")
	end

	assert(owner and name and owner:match(NAME_PATTERN) and name:match(NAME_PATTERN), `"{location}" is not owner/name`)

	local lowerHost = if host then host:lower() else "github.com"
	local configured: Source? = nil

	for _, source in sources do
		if source.kind == "github" and (source.host or "github.com"):lower() == lowerHost then
			configured = source
			break
		end
	end

	assert(configured or lowerHost == "github.com", `no GitHub source for {lowerHost}; add it first`)

	return {
		ref = {
			source = if configured then configured.id else "github",
			kind = "branch",
			type = "step",
			key = getGithubKey(assert(owner), assert(name), `@{branch}`, lowerHost),
		},
		repo = `{owner}/{name}`,
	}
end

-- Turns the value of --ref into a ref. A URL goes to whichever adapter
-- recognizes it; branch: records the branch work started on; source:key goes to
-- the configured source with that id, which its adapter parses.
local function resolveRef(input: string, sources: { Source }): ResolvedRef
	assert(input ~= "", "--ref needs a URL, source:key, or branch:owner/name@branch")

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
		error(`--ref takes a URL, source:key such as jira:ABC-1, or branch:owner/name@branch, not "{input}"`, 0)
	end

	if sourceId == BRANCH_PREFIX then
		return refFromBranch(key, sources)
	end

	local source = assert(findSource(sources, sourceId), `no source with id "{sourceId}"`)
	local refFromKey = getAdapter(source.kind).refFromKey
	assert(refFromKey, `{source.kind} sources can't attach refs with source:key; use a URL`)

	local ref = assert(refFromKey(key, source), `"{key}" is not a valid {source.kind} key`)

	return ref
end

return resolveRef
