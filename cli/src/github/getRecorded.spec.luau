local test = require("@std/test")

local getRecorded = require("@root/github/getRecorded")
local githubTypes = require("@root/github/types")

type PullState = githubTypes.PullState

test.case("recorded pull includes current review and check state", function(assert)
	local pull: PullState = {
		owner = "vocksel",
		name = "orion",
		number = 1,
		state = "OPEN",
		baseRefName = "main",
		headRefName = "feature",
		draft = false,
		title = "Title",
		url = "u",
		author = "vocksel",
		requestedReviewers = { "Vocksel" },
		updatedAt = "now",
		additions = 2,
		deletions = 1,
		reviewDecision = "APPROVED",
		checks = "SUCCESS",
		checkCounts = { total = 4, finished = 4, failed = 0 },
		mergeable = "MERGEABLE",
		mergeState = "CLEAN",
		head = "abc123",
		reviewRequests = 1,
	}
	local result = getRecorded(pull, "vocksel", "later")
	assert.eq(result.mine, true)
	assert.eq(result.requestedFromYou, true)
	assert.eq(result.checks, "SUCCESS")
	assert.eq((result.checkCounts :: any).finished, 4)
	assert.eq(result.mergeState, "CLEAN")
	assert.eq(result.head, "abc123")
end)
