local test = require("@std/test")

local fetchPullsAsync = require("@root/github/fetchPullsAsync")
local githubTypes = require("@root/github/types")
local testing = require("@root/testing")

type Ref = githubTypes.Ref

test.case("fetch batches pull requests into one GraphQL query", function(assert)
	local calls = 0
	local query = ""
	local found = fetchPullsAsync(function(argv)
		calls += 1
		query = argv[5]
		return testing.result(
			true,
			[[{"data":{"p1":{"pullRequest":{"number":658,"title":"Report release health","url":"u","state":"OPEN",]]
				.. [["baseRefName":"main","headRefName":"feature/a","isDraft":false,]]
				.. [["reviewDecision":"REVIEW_REQUIRED","reviewRequests":{"totalCount":2,]]
				.. [["nodes":[{"requestedReviewer":{"login":"vocksel"}}]},"author":{"login":"colleague"},]]
				.. [["updatedAt":"2026-10-04T18:00:00Z","additions":120,"deletions":30,]]
				.. [["commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING"}}}]}}},]]
				.. [["p2":{"pullRequest":null}}}]]
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
	local hit = found.pulls["flipbook-labs/flipbook#658"]
	assert.eq(hit and hit.reviewRequests, 2)
	assert.eq(hit and hit.author, "colleague")
	assert.eq(hit and hit.requestedReviewers[1], "vocksel")
	assert.eq(hit and hit.checks, "PENDING")
	assert.eq(hit and hit.baseRefName, "main")
	assert.eq(hit and hit.headRefName, "feature/a")
	assert.eq(found.pulls["flipbook-labs/flipbook#9999"], nil)
	assert.eq(found.checked["flipbook-labs/flipbook#9999"], true)
end)

test.case("fetch rejects repository names that would break the query", function(assert)
	assert.throws(function()
		fetchPullsAsync(function()
			return testing.result(true, "{}")
		end, { { owner = 'x") { evil }', name = "y", number = 1 } })
	end)
end)

local function refsTo(count: number): { Ref }
	local refs: { Ref } = {}

	for number = 1, count do
		table.insert(refs, { owner = "vocksel", name = "orion", number = number })
	end

	return refs
end

test.case("fetch halves a batch that times out and keeps the halves that pass", function(assert)
	local sizes: { number } = {}
	local found = fetchPullsAsync(function(argv)
		local query = argv[#argv]
		local _, size = query:gsub("pullRequest%(", "")
		table.insert(sizes, size)

		if query:find("number: 1)", 1, true) then
			return testing.result(false, "", "gh: HTTP 502")
		end

		return testing.result(true, [[{"data":{}}]])
	end, refsTo(4))

	assert.eq(sizes[1], 4)
	assert.eq(sizes[2], 2)
	assert.eq(#found.failures, 1)
	assert.strContains(found.failures[1], "vocksel/orion#1")
	assert.eq(found.checked["vocksel/orion#1"], nil)
	assert.eq(found.checked["vocksel/orion#2"], true)
	assert.eq(found.checked["vocksel/orion#3"], true)
	assert.eq(found.checked["vocksel/orion#4"], true)
end)

test.case("fetch reports a failure that isn't a timeout without retrying", function(assert)
	local calls = 0
	local found = fetchPullsAsync(function()
		calls += 1
		return testing.result(false, "", "gh: HTTP 401")
	end, refsTo(30))

	assert.eq(calls, 2)
	assert.eq(#found.failures, 2)
	assert.strContains(found.failures[1], "pull requests on github.com")
	assert.eq(next(found.checked), nil)
end)
