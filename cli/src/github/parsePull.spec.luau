local test = require("@std/test")

local json = require("@std/json")
local parsePull = require("@root/github/parsePull")

test.case("pull response preserves review and check details", function(assert)
	local object = json.asObject(
		json.deserialize(
			[[{"number":1,"state":"OPEN","url":"u","headRefName":"feature","reviewRequests":{"totalCount":1,"nodes":[{"requestedReviewer":{"login":"vocksel"}}]},"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING"}}}]}}]]
		) :: json.Value
	) :: json.Object
	local pull = parsePull(object, "vocksel", "orion")
	assert.eq(pull and pull.requestedReviewers[1], "vocksel")
	assert.eq(pull and pull.checks, "PENDING")
	assert.eq(pull and pull.branch, "feature")
end)
