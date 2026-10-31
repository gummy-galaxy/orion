local adapterTypes = require("@root/sources/types")
local getErrorText = require("@root/common/errors/getErrorText")
local getGithubId = require("@root/sources/github/refs/getGithubId")
local getRefKey = require("@root/sources/getRefKey")
local getRepoId = require("@root/sources/github/repositories/getRepoId")
local getString = require("@root/sources/github/getString")
local json = require("@std/json")
local queryAsync = require("@root/sources/github/api/queryAsync")
local types = require("@root/types")

type LookupResult = adapterTypes.LookupResult
type Ref = types.Ref
type ResolvedRef = types.ResolvedRef
type CommandRunner = types.CommandRunner

local BATCH_SIZE = 25
local PUBLIC_HOST = "github.com"

-- The ref's URL names its host. Only github.com is recognized without a
-- configured source, so other hosts come from one.
local function getHost(resolved: ResolvedRef): string
	local url = resolved.ref.url or ""
	return url:match("^https://([^/]+)/") or PUBLIC_HOST
end

local function getField(ref: Ref): string
	return if ref.kind == "pull" then "pullRequest" else "issue"
end

-- One aliased query per batch: each alias asks one repository for one pull
-- request or issue.
local function lookupBatchAsync(batch: { ResolvedRef }, host: string, run: CommandRunner, result: LookupResult)
	local parts = {}

	for index, resolved in batch do
		local owner, name = assert(resolved.repo, "GitHub refs name a repository"):match("^([^/]+)/([^/]+)$")
		local number = assert(resolved.ref.key:match("#(%d+)$"), "GitHub refs end in #number")
		local field = getField(resolved.ref)
		table.insert(
			parts,
			`p{index}: repository(owner: {json.serialize(assert(owner))}, name: `
				.. `{json.serialize(assert(name))}) \{ databaseId {field}(number: {number}) \{ title url } }`
		)
	end

	local succeeded, response =
		pcall(queryAsync, run, `query \{ {table.concat(parts, " ")} }`, if host == PUBLIC_HOST then nil else host)
	local data = if succeeded then response :: json.Object? else nil
	local failure = if succeeded
		then `GitHub lookup on {host} failed`
		else `GitHub lookup on {host} failed: {getErrorText(response)}`

	for index, resolved in batch do
		local ref = resolved.ref
		local key = getRefKey(ref)

		if not data then
			result.failures[key] = failure
			continue
		end

		local repository = json.asObject(data[`p{index}`])
		local item = if repository then json.asObject(repository[getField(ref)]) else nil
		local title = if item then getString(item.title) else nil

		if not item or not title then
			result.failures[key] = `not found on {host}`
			continue
		end

		local recorded = table.clone(ref)
		local repoId = getRepoId(repository)
		recorded.url = getString(item.url) or ref.url
		recorded.id = if repoId then getGithubId(repoId, assert(ref.key:match("[#@].*$")), host) else nil
		result.records[key] = {
			ref = recorded,
			label = title,
			repo = resolved.repo,
			createStatus = "todo",
			createWho = if ref.kind == "pull" then nil else "you",
		}
	end
end

-- Batches refs by host, so a list of issues across repositories costs one query
-- per 25 refs.
local function lookupRefsAsync(refs: { ResolvedRef }, _context: adapterTypes.Context, run: CommandRunner): LookupResult
	local result: LookupResult = { records = {}, failures = {} }
	local byHost: { [string]: { ResolvedRef } } = {}

	for _, resolved in refs do
		local host = getHost(resolved)
		byHost[host] = byHost[host] or {}
		table.insert(byHost[host], resolved)
	end

	for host, hostRefs in byHost do
		for start = 1, #hostRefs, BATCH_SIZE do
			local batch = table.move(hostRefs, start, math.min(start + BATCH_SIZE - 1, #hostRefs), 1, {})
			lookupBatchAsync(batch, host, run, result)
		end
	end

	return result
end

return lookupRefsAsync
