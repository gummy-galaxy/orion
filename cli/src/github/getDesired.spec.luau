local test = require("@std/test")

local getDesired = require("@root/github/getDesired")
local githubTypes = require("@root/github/types")

type PullState = githubTypes.PullState

local function pull(
	state: string,
	extra: { draft: boolean?, reviewDecision: string?, reviewRequests: number? }?
): PullState
	local given: { draft: boolean?, reviewDecision: string?, reviewRequests: number? } = extra or {}
	return {
		owner = "flipbook-labs",
		name = "flipbook",
		number = 1,
		state = state,
		baseRefName = "main",
		headRefName = "feature/a",
		draft = given.draft == true,
		reviewDecision = given.reviewDecision,
		reviewRequests = given.reviewRequests or 0,
		requestedReviewers = {},
		title = "Title",
		url = "https://github.com/flipbook-labs/flipbook/pull/1",
		author = "vocksel",
		updatedAt = "2026-10-04T00:00:00Z",
		additions = 12,
		deletions = 3,
		checks = "SUCCESS",
	}
end

test.case("desired follows the pull request's state", function(assert)
	assert.eq(getDesired(pull("MERGED"), "review", "review", "vocksel"), "done")
	assert.eq(getDesired(pull("CLOSED"), "active", "you", "vocksel"), "deferred")
	assert.eq(getDesired(pull("OPEN", { draft = true }), "todo", nil, "vocksel"), "active")
	local status, who = getDesired(pull("OPEN", { reviewRequests = 1 }), "active", "you", "vocksel")
	assert.eq(status, "review")
	assert.eq(who, "review")
	status, who = getDesired(pull("OPEN", { reviewDecision = "CHANGES_REQUESTED" }), "review", "review", "vocksel")
	assert.eq(status, "active")
	assert.eq(who, "you")
	status, who = getDesired(pull("OPEN", { reviewDecision = "APPROVED" }), "review", "review", "vocksel")
	assert.eq(status, "review")
	assert.eq(who, "you")
end)

test.case("desired keeps hand-set holds while the pull request is open", function(assert)
	assert.eq(getDesired(pull("OPEN", { reviewRequests = 1 }), "blocked", nil, "vocksel"), "blocked")
	assert.eq(getDesired(pull("OPEN"), "deferred", nil, "vocksel"), "deferred")
	assert.eq(getDesired(pull("MERGED"), "blocked", nil, "vocksel"), "done")
end)

test.case("desired tracks requested reviews on other people's pull requests", function(assert)
	local other = pull("OPEN")
	other.author = "colleague"
	other.requestedReviewers = { "vocksel" }
	local status, who = getDesired(other, "todo", nil, "vocksel")
	assert.eq(status, "review")
	assert.eq(who, "you")
	other.requestedReviewers = {}
	status, who = getDesired(other, "review", "you", "vocksel")
	assert.eq(status, "review")
	assert.eq(who, nil)
	assert.eq(getDesired(other, "blocked", "ci", "vocksel"), "blocked")
	other.state = "MERGED"
	assert.eq(getDesired(other, "review", "you", "vocksel"), "done")
end)
