local test = require("@std/test")

local fetchUpdatedAsync = require("@root/github/fetchUpdatedAsync")
local githubTypes = require("@root/github/types")
local testing = require("@root/testing")

type Ref = githubTypes.Ref

test.case("fetch updated asks only for updatedAt, 100 pull requests to a query", function(assert)
	local refs: { Ref } = {}

	for number = 1, 101 do
		table.insert(refs, { owner = "vocksel", name = "orion", number = number })
	end

	local queries: { string } = {}
	local result = fetchUpdatedAsync(function(argv)
		table.insert(queries, argv[#argv])
		return testing.result(true, [[{"data":{"p1":{"pullRequest":{"updatedAt":"2026-10-18T15:53:33Z"}}}}]])
	end, refs)

	assert.eq(#queries, 2)
	assert.strContains(queries[1], "pullRequest(number: 100) { updatedAt }")
	assert.eq(queries[1]:find("title", 1, true), nil)
	assert.eq(result.updatedAt["vocksel/orion#1"], "2026-10-18T15:53:33Z")
	assert.eq(result.updatedAt["vocksel/orion#2"], nil)
	assert.eq(#result.failures, 0)
end)
