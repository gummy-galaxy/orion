local test = require("@std/test")

local parseLatestRun = require("@lib/parseLatestRun")

test.case("parseLatestRun reads the run's id, status, and conclusion", function(assert)
	local run = parseLatestRun("12345\tcompleted\tsuccess\n")

	assert.eq(run ~= nil, true)
	assert.eq((run :: { id: string, status: string, conclusion: string? }).id, "12345")
	assert.eq((run :: { id: string, status: string, conclusion: string? }).status, "completed")
end)

test.case("parseLatestRun leaves the conclusion empty while a run is still going", function(assert)
	local run = parseLatestRun("12345\tin_progress\t\n")

	assert.eq(run ~= nil, true)
	assert.eq((run :: { id: string, status: string, conclusion: string? }).conclusion, nil)
end)

test.case("parseLatestRun returns nil when there is no run", function(assert)
	assert.eq(parseLatestRun(""), nil)
end)
