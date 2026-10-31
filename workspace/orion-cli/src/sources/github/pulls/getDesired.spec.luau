local test = require("@std/test")

local getDesired = require("@root/sources/github/pulls/getDesired")
local testing = require("@root/testing")

local pull = testing.pull

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
