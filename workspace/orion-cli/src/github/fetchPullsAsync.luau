local getKey = require("@root/github/getKey")
local getPullFields = require("@root/github/getPullFields")
local githubTypes = require("@root/github/types")
local parsePull = require("@root/github/parsePull")
local queryPullsAsync = require("@root/github/queryPullsAsync")
local types = require("@root/types")

type Ref = githubTypes.Ref
type PullResult = githubTypes.PullResult
type CommandRunner = types.CommandRunner

local BATCH_SIZE = 25

--[[
	Fetches the full state of each pull request, 25 to a query. A batch that
	still fails after halving is reported in `failures` rather than raised, so
	the other batches keep their results. `checked` holds the keys each
	successful query covered, found or not.
]]
local function fetchPullsAsync(run: CommandRunner, refs: { Ref }): PullResult
	local queried = queryPullsAsync(run, refs, getPullFields(), BATCH_SIZE)
	local result: PullResult = { pulls = {}, checked = queried.checked, failures = queried.failures }

	for _, ref in refs do
		local key = getKey(ref)
		local object = queried.objects[key]
		local parsed = if object then parsePull(object, ref.owner, ref.name, ref.host) else nil

		if parsed then
			result.pulls[key] = parsed
		end
	end

	return result
end

return fetchPullsAsync
