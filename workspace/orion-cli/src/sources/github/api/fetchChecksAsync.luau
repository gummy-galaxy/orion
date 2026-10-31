local getCheckFields = require("@root/sources/github/checks/getCheckFields")
local getKey = require("@root/sources/github/refs/getKey")
local githubTypes = require("@root/sources/github/types")
local parsePull = require("@root/sources/github/pulls/parsePull")
local queryPullsAsync = require("@root/sources/github/api/queryPullsAsync")
local types = require("@root/types")

type Ref = githubTypes.Ref
type PullResult = githubTypes.PullResult
type CommandRunner = types.CommandRunner

local BATCH_SIZE = 50

--[[
	Fetches only the checks on each pull request's latest commit, with the head
	they ran on, so a refresh can fully fetch only the ones whose checks moved.
	A finished check run doesn't move `updatedAt` or produce a notification.
]]
local function fetchChecksAsync(run: CommandRunner, refs: { Ref }): PullResult
	local queried = queryPullsAsync(run, refs, `number state url headRefOid {getCheckFields()}`, BATCH_SIZE)
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

return fetchChecksAsync
