local test = require("@std/test")

local getCheckState = require("@root/sources/github/checks/getCheckState")
local json = require("@std/json")

local function rollup(source: string): json.Object
	return json.asObject(json.deserialize(source) :: json.Value) :: json.Object
end

test.case("check state stays pending when a cancelled job sits beside unfinished ones", function(assert)
	assert.eq(
		getCheckState(
			rollup(
				[[{"state":"FAILURE","contexts":{"checkRunCountsByState":[{"state":"CANCELLED","count":1},]]
					.. [[{"state":"QUEUED","count":2},{"state":"SUCCESS","count":3}]}}]]
			)
		),
		"PENDING"
	)
end)

test.case("check state fails on a real failure even while others run", function(assert)
	assert.eq(
		getCheckState(
			rollup(
				[[{"state":"FAILURE","contexts":{"checkRunCountsByState":[{"state":"FAILURE","count":1},]]
					.. [[{"state":"IN_PROGRESS","count":1}]}}]]
			)
		),
		"FAILURE"
	)
	assert.eq(
		getCheckState(
			rollup([[{"state":"FAILURE","contexts":{"statusContextCountsByState":[{"state":"ERROR","count":1}]}}]])
		),
		"FAILURE"
	)
	assert.eq(
		getCheckState(
			rollup([[{"state":"FAILURE","contexts":{"checkRunCountsByState":[{"state":"TIMED_OUT","count":1}]}}]])
		),
		"FAILURE"
	)
end)

test.case("check state succeeds when the only other jobs were cancelled or skipped", function(assert)
	assert.eq(
		getCheckState(
			rollup(
				[[{"state":"FAILURE","contexts":{"checkRunCountsByState":[{"state":"CANCELLED","count":1},]]
					.. [[{"state":"SKIPPED","count":1},{"state":"SUCCESS","count":4}]}}]]
			)
		),
		"SUCCESS"
	)
end)

test.case("check state falls back to GitHub's rollup without counts", function(assert)
	assert.eq(getCheckState(rollup([[{"state":"SUCCESS"}]])), "SUCCESS")
	assert.eq(getCheckState(rollup([[{"state":"PENDING","contexts":{}}]])), "PENDING")
end)
