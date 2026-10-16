local getKey = require("@root/github/getKey")
local getPullFields = require("@root/github/getPullFields")
local githubTypes = require("@root/github/types")
local isTimeout = require("@root/github/isTimeout")
local json = require("@std/json")
local parsePull = require("@root/github/parsePull")
local query = require("@root/github/query")
local types = require("@root/types")

type Ref = githubTypes.Ref
type PullResult = githubTypes.PullResult
type CommandRunner = types.CommandRunner

local BATCH_SIZE = 25
local NAME_PATTERN = "^[%w%-%._]+$"

-- Queries one batch, halving it and trying each half when GitHub times out, until a single pull request fails alone.
local function fetchBatch(run: CommandRunner, host: string, refs: { Ref }, result: PullResult)
	local parts = {}
	local batch: { [string]: Ref } = {}

	for index, ref in refs do
		local alias = `p{index}`
		batch[alias] = ref
		table.insert(
			parts,
			`{alias}: repository(owner: "{ref.owner}", name: "{ref.name}") \{ pullRequest(number: {ref.number}) \{ {getPullFields()} } }`
		)
	end

	local succeeded, data =
		pcall(query, run, `query \{ {table.concat(parts, " ")} }`, if host == "github.com" then nil else host)

	if not succeeded or data == nil then
		local message = if succeeded then "GitHub returned no data" else tostring(data)

		if isTimeout(message) and #refs > 1 then
			local middle = #refs // 2
			fetchBatch(run, host, table.move(refs, 1, middle, 1, {}), result)
			fetchBatch(run, host, table.move(refs, middle + 1, #refs, 1, {}), result)
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
		local parsed = if pull then parsePull(pull, ref.owner, ref.name, ref.host) else nil
		result.checked[key] = true

		if parsed then
			result.pulls[key] = parsed
		end
	end
end

--[[
	Fetches the full state of each pull request, 25 to a query. A batch that still fails after halving is reported in
	`failures` rather than raised, so the other batches keep their results. `checked` holds the keys each successful
	query covered, found or not.
]]
local function fetchPulls(run: CommandRunner, refs: { Ref }): PullResult
	local result: PullResult = { pulls = {}, checked = {}, failures = {} }
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
		for start = 1, #hostRefs, BATCH_SIZE do
			local batch = table.move(hostRefs, start, math.min(start + BATCH_SIZE - 1, #hostRefs), 1, {})
			fetchBatch(run, host, batch, result)
		end
	end

	return result
end

return fetchPulls
