local test = require("@std/test")

local getWatchDecision = require("@root/prioritize/getWatchDecision")
local types = require("@root/prioritize/types")

type Job = types.Job

local function job(name: string, status: string, conclusion: string?): Job
	return { name = name, status = status, conclusion = conclusion }
end

test.case("getWatchDecision keeps watching while the perf job is queued", function(assert)
	local decision = getWatchDecision({ job("changes", "completed", "success"), job("perf", "queued", nil) }, false)

	assert.eq(decision.stop, false)
end)

test.case("getWatchDecision stops once the perf job is running", function(assert)
	local decision = getWatchDecision({ job("perf", "in_progress", nil) }, false)

	assert.eq(decision.stop, true)
	assert.eq(decision.reason, "perf job is running")
end)

test.case("getWatchDecision stops once the perf job has finished", function(assert)
	local decision = getWatchDecision({ job("perf", "completed", "failure") }, true)

	assert.eq(decision.stop, true)
	assert.eq(decision.reason, "perf job finished")
end)

test.case("getWatchDecision stops when the perf job was skipped", function(assert)
	local decision =
		getWatchDecision({ job("changes", "completed", "success"), job("perf", "completed", "skipped") }, false)

	assert.eq(decision.stop, true)
	assert.eq(decision.reason, "perf job was skipped")
end)

test.case("getWatchDecision stops when the run finished without a perf job", function(assert)
	local decision = getWatchDecision({ job("changes", "completed", "success") }, true)

	assert.eq(decision.stop, true)
	assert.eq(decision.reason, "CI finished without a perf job")
end)

test.case("getWatchDecision keeps waiting for a run that has not queued its perf job", function(assert)
	local decision = getWatchDecision({ job("changes", "in_progress", nil) }, false)

	assert.eq(decision.stop, false)
end)
