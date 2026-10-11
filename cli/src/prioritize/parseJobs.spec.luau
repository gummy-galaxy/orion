local test = require("@std/test")

local parseJobs = require("@root/prioritize/parseJobs")

test.case("parseJobs reads each job's name, status, and conclusion", function(assert)
	local jobs = parseJobs("perf\tcompleted\tsuccess\nchanges\tqueued\t\n")

	assert.eq(#jobs, 2)
	assert.eq(jobs[1].name, "perf")
	assert.eq(jobs[1].status, "completed")
	assert.eq(jobs[1].conclusion, "success")
	assert.eq(jobs[2].name, "changes")
	assert.eq(jobs[2].status, "queued")
	assert.eq(jobs[2].conclusion, nil)
end)

test.case("parseJobs returns no jobs for empty output", function(assert)
	assert.eq(#parseJobs(""), 0)
end)
