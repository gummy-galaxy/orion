local json = require("@std/json")
local test = require("@std/test")

local getSnoozedFacts = require("@root/sources/github/pulls/getSnoozedFacts")
local testing = require("@root/testing")
local types = require("@root/types")

type CheckSnooze = types.CheckSnooze

local NOW = "2026-10-13T12:00:00Z"

local function card(details: { [string]: any }, key: string?): types.Item
	local recorded = json.object({
		state = "OPEN",
		draft = false,
		checks = "FAILURE",
		checkCounts = json.object({ total = 6, finished = 6, failed = 1 }),
		failedChecks = { json.object({ name = "docs" }) },
		mergeState = "BLOCKED",
	})

	for field, value in details do
		recorded[field] = value
	end

	local ref = json.object({ source = "github", kind = "pull", key = key or "vocksel/orion#12", details = recorded })

	return testing.task("card", "Card", "review", nil, json.object({ refs = { ref } }))
end

local function docs(overrides: { [string]: any }?): CheckSnooze
	local snooze: { [string]: any } =
		{ repo = "vocksel/orion", name = "docs", at = "2026-10-13T00:00:00Z", passed = {} }

	for field, value in overrides or {} do
		snooze[field] = value
	end

	return snooze :: CheckSnooze
end

test.case("getSnoozedFacts reads checks as passing once the only failure is snoozed", function(assert)
	local facts = getSnoozedFacts(card({}), { docs() }, NOW)
	local checks = (facts and facts.checks) :: json.Object

	assert.eq(facts and facts.readiness, "passing")
	assert.eq(checks.state, "passing")
	assert.eq(checks.failed, 0)
	assert.eq(facts and facts.snoozed[1].name, "docs")
	assert.eq(facts and facts.wakesAt, nil)
end)

test.case("getSnoozedFacts reads checks as running while other jobs haven't finished", function(assert)
	local counts = json.object({ total = 6, finished = 4, failed = 1 })
	local running = getSnoozedFacts(card({ checkCounts = counts, checkProgress = "running" }), { docs() }, NOW)
	local waiting = getSnoozedFacts(card({ checkCounts = counts, checkProgress = "waiting" }), { docs() }, NOW)

	assert.eq(running and running.readiness, "running")
	assert.eq(running and (running.checks :: json.Object).state, "pending")
	assert.eq(waiting and waiting.readiness, "waiting")
end)

test.case("getSnoozedFacts reads a clean pull request as ready to merge", function(assert)
	local facts = getSnoozedFacts(card({ mergeState = "CLEAN" }), { docs() }, NOW)

	assert.eq(facts and facts.readiness, "mergeable")
end)

test.case("getSnoozedFacts keeps checks failing while another job still fails", function(assert)
	local failedChecks = { json.object({ name = "docs" }), json.object({ name = "test" }) }
	local counts = json.object({ total = 6, finished = 6, failed = 2 })
	local facts = getSnoozedFacts(card({ failedChecks = failedChecks, checkCounts = counts }), { docs() }, NOW)
	local checks = (facts and facts.checks) :: json.Object

	assert.eq(facts and facts.readiness, "failing")
	assert.eq(checks.state, "failing")
	assert.eq(checks.failed, 1)
	assert.eq(#(facts and facts.snoozed or {}), 1)
end)

test.case("getSnoozedFacts keeps a conflict ahead of the checks", function(assert)
	local facts = getSnoozedFacts(card({ mergeable = "CONFLICTING" }), { docs() }, NOW)

	assert.eq(facts and facts.readiness, "conflict")
	assert.eq(facts and (facts.checks :: json.Object).state, "passing")
end)

test.case("getSnoozedFacts stops leaving a job out once a timed snooze ends", function(assert)
	local later = getSnoozedFacts(card({}), { docs({ untilTime = "2026-10-13T13:00:00Z" }) }, NOW)
	local ended = getSnoozedFacts(card({}), { docs({ untilTime = "2026-10-13T11:00:00Z" }) }, NOW)

	assert.eq(later and later.readiness, "passing")
	assert.eq(later and later.wakesAt, "2026-10-13T13:00:00Z")
	assert.eq(later and later.snoozed[1].untilTime, "2026-10-13T13:00:00Z")
	assert.eq(ended, nil)
end)

test.case("getSnoozedFacts shows a failure again on a card where the job has passed since", function(assert)
	assert.eq(getSnoozedFacts(card({}), { docs({ passed = { "card" } }) }, NOW), nil)
	assert.eq(getSnoozedFacts(card({}), { docs({ passed = { "other" } }) }, NOW) ~= nil, true)
end)

test.case("getSnoozedFacts matches the repository without case and skips other jobs and repositories", function(assert)
	assert.eq(getSnoozedFacts(card({}, "Vocksel/Orion#12"), { docs() }, NOW) ~= nil, true)
	assert.eq(getSnoozedFacts(card({}, "github.example.com/vocksel/orion#12"), { docs() }, NOW) ~= nil, true)
	assert.eq(getSnoozedFacts(card({}), { docs({ repo = "vocksel/hop" }) }, NOW), nil)
	assert.eq(getSnoozedFacts(card({}), { docs({ name = "Docs" }) }, NOW), nil)
	assert.eq(getSnoozedFacts(card({}), {}, NOW), nil)
end)

test.case("getSnoozedFacts never counts an optional failure as snoozed", function(assert)
	local failedChecks = { json.object({ name = "docs", optional = true }) }

	assert.eq(getSnoozedFacts(card({ failedChecks = failedChecks, checks = "SUCCESS" }), { docs() }, NOW), nil)
end)

test.case("getSnoozedFacts leaves closed pull requests alone", function(assert)
	assert.eq(getSnoozedFacts(card({ state = "MERGED" }), { docs() }, NOW), nil)
end)
