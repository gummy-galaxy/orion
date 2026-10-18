local json = require("@std/json")
local test = require("@std/test")

local setPullFacts = require("@root/github/setPullFacts")
local types = require("@root/types")

type Ref = types.Ref

local OPEN = {
	state = "OPEN",
	draft = false,
	author = "vocksel",
	mine = true,
	requestedFromYou = false,
	additions = 3,
	deletions = 1,
	checkedAt = "2026-10-17T00:00:00Z",
	head = "abc123",
}

local function getFacts(fields: { [string]: any }): Ref
	local details = json.object(OPEN :: any)

	for field, value in fields do
		details[field] = value
	end

	local ref: Ref = { source = "github", kind = "pull", key = "vocksel/orion#1" }
	setPullFacts(ref, details)
	return ref
end

test.case("setPullFacts reads how close an open pull request is to merging", function(assert)
	assert.eq(getFacts({ mergeable = "CONFLICTING", checks = "SUCCESS" }).readiness, "conflict")
	assert.eq(getFacts({ mergeState = "DIRTY" }).readiness, "conflict")
	assert.eq(getFacts({ checks = "ERROR", mergeState = "CLEAN" }).readiness, "failing")
	assert.eq(getFacts({ checks = "PENDING" }).readiness, "running")
	assert.eq(getFacts({ checks = "EXPECTED", checkProgress = "waiting" }).readiness, "waiting")
	assert.eq(getFacts({ checks = "SUCCESS", mergeState = "HAS_HOOKS" }).readiness, "mergeable")
	assert.eq(getFacts({ checks = "SUCCESS", mergeState = "CLEAN", draft = true }).readiness, "passing")
	assert.eq(getFacts({ checks = "SUCCESS", mergeState = "BLOCKED" }).readiness, "passing")
	assert.eq(getFacts({ mergeState = "BLOCKED" }).readiness, nil)
	assert.eq(getFacts({ state = "MERGED", mergeState = "CLEAN" }).readiness, nil)
end)

test.case("setPullFacts names the state the way GitHub shows it", function(assert)
	assert.eq(getFacts({}).stateLabel, "Open on GitHub")
	assert.eq(getFacts({ draft = true, reviewDecision = "APPROVED" }).stateLabel, "Draft on GitHub")
	assert.eq(getFacts({ reviewDecision = "APPROVED" }).stateLabel, "Approved on GitHub")
	assert.eq(getFacts({ reviewDecision = "REVIEW_REQUIRED" }).stateLabel, "Awaiting review on GitHub")
	assert.eq(getFacts({ state = "MERGED" }).stateLabel, "Merged on GitHub")
	assert.eq(getFacts({ state = "CLOSED" }).stateLabel, "Closed on GitHub")
end)

test.case("setPullFacts keeps check counts and progress only while the pull request is open", function(assert)
	local counts = json.object({ total = 8, finished = 5, failed = 1 })
	local open = getFacts({ checks = "PENDING", checkProgress = "running", checkCounts = counts })
	local checks = open.checks :: json.Object

	assert.eq(checks.state, "pending")
	assert.eq(checks.progress, "running")
	assert.eq(checks.total, 8)
	assert.eq(checks.finished, 5)
	assert.eq(checks.failed, 1)

	local merged = getFacts({ state = "MERGED", checks = "FAILURE", checkProgress = "running", checkCounts = counts })
	local mergedChecks = merged.checks :: json.Object

	assert.eq(mergedChecks.state, "failing")
	assert.eq(mergedChecks.progress, nil)
	assert.eq(mergedChecks.total, nil)
	assert.eq(getFacts({}).checks, nil)
end)

test.case("setPullFacts carries who wrote it, the review ask, the size, and the head", function(assert)
	local ref = getFacts({ reviewDecision = "CHANGES_REQUESTED", requestedFromYou = true })

	assert.eq(ref.changesRequested, true)
	assert.eq(ref.isReviewRequested, true)
	assert.eq(ref.author, "vocksel")
	assert.eq(ref.isMine, true)
	assert.eq(ref.additions, 3)
	assert.eq(ref.deletions, 1)
	assert.eq(ref.head, "abc123")
	assert.eq(ref.checkedAt, "2026-10-17T00:00:00Z")
	assert.eq(getFacts({}).changesRequested, nil)
end)

test.case("setPullFacts clears facts the details no longer support", function(assert)
	local ref: Ref = { source = "github", kind = "pull", key = "vocksel/orion#1" }
	setPullFacts(ref, json.object({ state = "OPEN", draft = false, checks = "SUCCESS", mergeState = "CLEAN" }))
	assert.eq(ref.readiness, "mergeable")

	setPullFacts(ref, json.object({ state = "MERGED", draft = false }))
	assert.eq(ref.readiness, nil)
	assert.eq(ref.checks, nil)
	assert.eq(ref.stateLabel, "Merged on GitHub")
end)
