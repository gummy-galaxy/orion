local json = require("@std/json")
local test = require("@std/test")

local getRecorded = require("@root/sources/github/pulls/getRecorded")
local githubTypes = require("@root/sources/github/types")

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

test.case("recorded pull lists failed jobs and marks the optional ones", function(assert)
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
		requestedReviewers = {},
		updatedAt = "now",
		additions = 0,
		deletions = 0,
		reviewRequests = 0,
		checks = "FAILURE",
		failedChecks = { { name = "test", optional = false }, { name = "docs", optional = true } },
	}
	local recorded = getRecorded(pull, "vocksel", "now")
	local failed = json.asArray(recorded.failedChecks) or {}
	local first = json.asObject(failed[1]) or json.object({})
	local second = json.asObject(failed[2]) or json.object({})

	assert.eq(first.name, "test")
	assert.eq(first.optional, nil)
	assert.eq(second.name, "docs")
	assert.eq(second.optional, true)
end)
