local json = require("@std/json")

local getKey = require("@root/sources/github/refs/getKey")
local githubTypes = require("@root/sources/github/types")
local isTimeout = require("@root/sources/github/api/isTimeout")
local queryAsync = require("@root/sources/github/api/queryAsync")
local types = require("@root/types")

type Ref = githubTypes.Ref
type CommandRunner = types.CommandRunner

export type QueryResult = {
	objects: { [string]: json.Object },
	checked: { [string]: boolean },
	failures: { string },
}

local NAME_PATTERN = "^[%w%-%._]+$"

-- Queries one batch, halving it and trying each half when GitHub times out,
-- until a single pull request fails alone.
local function queryBatchAsync(run: CommandRunner, host: string, refs: { Ref }, fields: string, result: QueryResult)
	local parts = {}
	local batch: { [string]: Ref } = {}

	for index, ref in refs do
		local alias = `p{index}`
		batch[alias] = ref
		table.insert(
			parts,
			`{alias}: repository(owner: "{ref.owner}", name: "{ref.name}") \{ pullRequest(number: {ref.number}) \{ {fields} } }`
		)
	end

	local succeeded, data =
		pcall(queryAsync, run, `query \{ {table.concat(parts, " ")} }`, if host == "github.com" then nil else host)

	if not succeeded or data == nil then
		local message = if succeeded then "GitHub returned no data" else tostring(data)

		if isTimeout(message) and #refs > 1 then
			local middle = #refs // 2
			queryBatchAsync(run, host, table.move(refs, 1, middle, 1, {}), fields, result)
			queryBatchAsync(run, host, table.move(refs, middle + 1, #refs, 1, {}), fields, result)
		else
			local subject = if #refs == 1 then getKey(refs[1]) else `{#refs} pull requests on {host}`
			table.insert(result.failures, `{subject}: {message}`)
		end

		return
	end

	for alias, ref in batch do
		local key = getKey(ref)
		local repository = json.asObject(data[alias])
		local pull = if repository then json.asObject(repository.pullRequest) else nil
		result.checked[key] = true

		if pull then
			result.objects[key] = pull
		end
	end
end

--[[
	Queries `fields` on each pull request, `batchSize` to a query, keyed by
	`getKey`. A batch that still fails after halving is reported in `failures`
	rather than raised, so the other batches keep their results. `checked` holds
	the keys each successful query covered, found or not.
]]
local function queryPullsAsync(run: CommandRunner, refs: { Ref }, fields: string, batchSize: number): QueryResult
	local result: QueryResult = { objects = {}, checked = {}, failures = {} }
	local byHost: { [string]: { Ref } } = {}

	for _, ref in refs do
		assert(
			ref.owner:match(NAME_PATTERN) and ref.name:match(NAME_PATTERN),
			`invalid repository {ref.owner}/{ref.name}`
		)
		local host = ref.host or "github.com"
		byHost[host] = byHost[host] or {}
		table.insert(byHost[host], ref)
	end

	for host, hostRefs in byHost do
		for start = 1, #hostRefs, batchSize do
			local batch = table.move(hostRefs, start, math.min(start + batchSize - 1, #hostRefs), 1, {})
			queryBatchAsync(run, host, batch, fields, result)
		end
	end

	return result
end

return queryPullsAsync
