local test = require("@std/test")

local fetchPulls = require("@root/github/fetchPulls")
local testing = require("@root/testing")

test.case("fetch batches pull requests into one GraphQL query", function(assert)
	local calls = 0
	local query = ""
	local found = fetchPulls(function(argv)
		calls += 1
		query = argv[5]
		return testing.result(
			true,
			[[{"data":{"p1":{"pullRequest":{"number":658,"title":"Report release health","url":"u","state":"OPEN","baseRefName":"main","headRefName":"feature/a","isDraft":false,"reviewDecision":"REVIEW_REQUIRED","reviewRequests":{"totalCount":2,"nodes":[{"requestedReviewer":{"login":"vocksel"}}]},"author":{"login":"colleague"},"updatedAt":"2026-10-04T18:00:00Z","additions":120,"deletions":30,"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING"}}}]}}},"p2":{"pullRequest":null}}}]]
		)
	end, {
		{ owner = "flipbook-labs", name = "flipbook", number = 658 },
		{ owner = "flipbook-labs", name = "flipbook", number = 9999 },
	})
	assert.eq(calls, 1)
	assert.strContains(query, "pullRequest(number: 658)")
	assert.strContains(query, "statusCheckRollup")
	assert.strContains(query, "requestedReviewer")
	assert.strContains(query, "baseRefName headRefName")
	assert.strContains(query, "title body url")
	local hit = found["flipbook-labs/flipbook#658"]
	assert.eq(hit and hit.reviewRequests, 2)
	assert.eq(hit and hit.author, "colleague")
	assert.eq(hit and hit.requestedReviewers[1], "vocksel")
	assert.eq(hit and hit.checks, "PENDING")
	assert.eq(hit and hit.baseRefName, "main")
	assert.eq(hit and hit.headRefName, "feature/a")
	assert.eq(found["flipbook-labs/flipbook#9999"], nil)
end)

test.case("fetch rejects repository names that would break the query", function(assert)
	assert.throws(function()
		fetchPulls(function()
			return testing.result(true, "{}")
		end, { { owner = 'x") { evil }', name = "y", number = 1 } })
	end)
end)
