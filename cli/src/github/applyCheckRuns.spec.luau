local test = require("@std/test")

local applyCheckRuns = require("@root/github/applyCheckRuns")
local githubTypes = require("@root/github/types")

type PullState = githubTypes.PullState

local function failingPull(failed: number): PullState
	return {
		owner = "vocksel",
		name = "orion",
		number = 1,
		state = "OPEN",
		baseRefName = "main",
		headRefName = "feature",
		draft = false,
		reviewRequests = 0,
		requestedReviewers = {},
		title = "Title",
		url = "u",
		author = "vocksel",
		updatedAt = "now",
		additions = 0,
		deletions = 0,
		checks = "FAILURE",
		checkCounts = { total = 4, finished = 4, failed = failed },
	}
end

test.case("an optional job's failure no longer fails a pull request whose other jobs are required", function(assert)
	local pull = failingPull(1)
	applyCheckRuns(pull, {
		{ name = "test", state = "passed", required = true },
		{ name = "docs", state = "failed", required = false },
		{ name = "lint", state = "passed", required = true },
		{ name = "perf", state = "other", required = false },
	})

	assert.eq(pull.checks, "SUCCESS")
	assert.eq(pull.checkCounts and pull.checkCounts.failed, 0)
	assert.eq(pull.failedChecks and pull.failedChecks[1].name, "docs")
	assert.eq(pull.failedChecks and pull.failedChecks[1].optional, true)
	assert.eq(table.concat(pull.passedChecks or {}, ","), "test,lint")
end)

test.case("a required job's failure still fails the pull request", function(assert)
	local pull = failingPull(2)
	applyCheckRuns(pull, {
		{ name = "test", state = "failed", required = true },
		{ name = "docs", state = "failed", required = false },
	})

	assert.eq(pull.checks, "FAILURE")
	assert.eq(pull.checkCounts and pull.checkCounts.failed, 1)
	assert.eq(pull.failedChecks and pull.failedChecks[1].optional, false)
end)

test.case("every failure counts when no job is required", function(assert)
	local pull = failingPull(1)
	applyCheckRuns(pull, { { name = "docs", state = "failed", required = false } })

	assert.eq(pull.checks, "FAILURE")
	assert.eq(pull.failedChecks and pull.failedChecks[1].optional, false)
end)

test.case("checks still running read as pending once optional failures are left out", function(assert)
	local pull = failingPull(1)
	pull.checkCounts = { total = 4, finished = 3, failed = 1 }
	applyCheckRuns(pull, {
		{ name = "test", state = "pending", required = true },
		{ name = "docs", state = "failed", required = false },
	})

	assert.eq(pull.checks, "PENDING")
end)
