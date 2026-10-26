local getString = require("@root/github/getString")
local githubTypes = require("@root/github/types")
local queryPullsAsync = require("@root/github/queryPullsAsync")
local types = require("@root/types")

type Ref = githubTypes.Ref
type CommandRunner = types.CommandRunner

export type UpdatedResult = { updatedAt: { [string]: string }, failures: { string } }

-- Light enough that 100 pull requests answer in under a second.
local BATCH_SIZE = 100

--[[
	Fetches when each pull request last changed, keyed by `getKey`, so a refresh
	can fully fetch only the ones that moved. `updatedAt` moves on pushes,
	reviews, comments, edits, and state changes, including the viewer's own, but
	not when a check run finishes.
]]
local function fetchUpdatedAsync(run: CommandRunner, refs: { Ref }): UpdatedResult
	local queried = queryPullsAsync(run, refs, "updatedAt", BATCH_SIZE)
	local updatedAt: { [string]: string } = {}

	for key, object in queried.objects do
		local time = getString(object.updatedAt)

		if time then
			updatedAt[key] = time
		end
	end

	return { updatedAt = updatedAt, failures = queried.failures }
end

return fetchUpdatedAsync
