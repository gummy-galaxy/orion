local test = require("@std/test")

local getCheckProgress = require("@root/github/getCheckProgress")
local json = require("@std/json")

local function rollup(source: string): json.Object
	return json.asObject(json.deserialize(source) :: json.Value) :: json.Object
end

test.case("check progress is running once any check starts", function(assert)
	assert.eq(
		getCheckProgress(
			rollup(
				[[{"contexts":{"checkRunCountsByState":[{"state":"QUEUED","count":3},{"state":"IN_PROGRESS","count":1}]}}]]
			)
		),
		"running"
	)
	assert.eq(
		getCheckProgress(rollup([[{"contexts":{"statusContextCountsByState":[{"state":"PENDING","count":1}]}}]])),
		"running"
	)
end)

test.case("check progress is waiting while every unfinished check is queued", function(assert)
	assert.eq(
		getCheckProgress(
			rollup(
				[[{"contexts":{"checkRunCountsByState":[{"state":"QUEUED","count":2},{"state":"SUCCESS",]]
					.. [["count":4},{"state":"IN_PROGRESS","count":0}],]]
					.. [["statusContextCountsByState":[{"state":"EXPECTED","count":1}]}}]]
			)
		),
		"waiting"
	)
end)

test.case("check progress is absent once checks finish or without counts", function(assert)
	assert.eq(getCheckProgress(rollup([[{"contexts":{"checkRunCountsByState":[{"state":"SUCCESS","count":2}]}}]])), nil)
	assert.eq(getCheckProgress(rollup([[{"state":"SUCCESS"}]])), nil)
end)
