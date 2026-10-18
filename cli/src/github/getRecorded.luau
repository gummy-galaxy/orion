local githubTypes = require("@root/github/types")
local isRequestedFrom = require("@root/github/isRequestedFrom")
local json = require("@std/json")

type PullState = githubTypes.PullState

local function getRecorded(pull: PullState, viewer: string, checkedAt: string): json.Object
	local result = json.object({
		state = pull.state,
		draft = pull.draft,
		title = pull.title,
		url = pull.url,
		author = pull.author,
		mine = pull.author:lower() == viewer:lower(),
		requestedFromYou = isRequestedFrom(pull, viewer),
		updatedAt = pull.updatedAt,
		additions = pull.additions,
		deletions = pull.deletions,
		checkedAt = checkedAt,
	})
	result.reviewDecision = pull.reviewDecision
	result.checks = pull.checks
	result.checkProgress = pull.checkProgress
	result.checkCounts = if pull.checkCounts
		then json.object({
			total = pull.checkCounts.total,
			finished = pull.checkCounts.finished,
			failed = pull.checkCounts.failed,
		})
		else nil
	if pull.failedChecks then
		local failedChecks: json.Array = {}

		for _, check in pull.failedChecks do
			local value = json.object({ name = check.name })
			value.optional = if check.optional then true else nil
			table.insert(failedChecks, value)
		end

		result.failedChecks = failedChecks
	end

	result.mergeable = pull.mergeable
	result.mergeState = pull.mergeState
	result.head = pull.head
	return result
end

return getRecorded
