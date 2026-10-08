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
	return result
end

return getRecorded
