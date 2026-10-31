local test = require("@std/test")

local getCheckCounts = require("@root/github/getCheckCounts")
local json = require("@std/json")

local function rollup(source: string): json.Object
	return json.asObject(json.deserialize(source) :: json.Value) :: json.Object
end

test.case("check counts add check runs and status contexts", function(assert)
	local counts = getCheckCounts(
		rollup(
			[[{"contexts":{"checkRunCountsByState":[{"state":"SUCCESS","count":3},]]
				.. [[{"state":"FAILURE","count":1},{"state":"IN_PROGRESS","count":2},]]
				.. [[{"state":"QUEUED","count":1}],]]
				.. [["statusContextCountsByState":[{"state":"SUCCESS","count":1},{"state":"PENDING","count":1}]}}]]
		)
	)

	assert.eq(counts and counts.total, 9)
	assert.eq(counts and counts.finished, 5)
	assert.eq(counts and counts.failed, 1)
end)

test.case("check counts treat cancelled and skipped checks as finished without failing", function(assert)
	local counts = getCheckCounts(
		rollup(
			[[{"contexts":{"checkRunCountsByState":[{"state":"CANCELLED","count":1},{"state":"SKIPPED","count":2},]]
				.. [[{"state":"SUCCESS","count":1}]}}]]
		)
	)

	assert.eq(counts and counts.finished, 4)
	assert.eq(counts and counts.failed, 0)
end)

test.case("check counts are absent without per-state counts or checks", function(assert)
	assert.eq(getCheckCounts(rollup([[{"state":"SUCCESS"}]])), nil)
	assert.eq(getCheckCounts(rollup([[{"state":"PENDING","contexts":{}}]])), nil)
end)
