local test = require("@std/test")

local json = require("@std/json")
local parsePull = require("@root/github/parsePull")

test.case("pull response preserves review and check details", function(assert)
	local object = json.asObject(
		json.deserialize(
			[[{"number":1,"state":"OPEN","url":"u","headRefName":"feature","reviewRequests":{"totalCount":1,"nodes":[{"requestedReviewer":{"login":"vocksel"}}]},"mergeable":"CONFLICTING","mergeStateStatus":"DIRTY","headRefOid":"abc123","commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING","contexts":{"checkRunCountsByState":[{"state":"QUEUED","count":1}]}}}}]}}]]
		) :: json.Value
	) :: json.Object
	local pull = parsePull(object, "vocksel", "orion")
	assert.eq(pull and pull.requestedReviewers[1], "vocksel")
	assert.eq(pull and pull.checks, "PENDING")
	assert.eq(pull and pull.checkProgress, "waiting")
	assert.eq(pull and pull.mergeable, "CONFLICTING")
	assert.eq(pull and pull.mergeState, "DIRTY")
	assert.eq(pull and pull.head, "abc123")
	assert.eq(pull and pull.branch, "feature")
end)
