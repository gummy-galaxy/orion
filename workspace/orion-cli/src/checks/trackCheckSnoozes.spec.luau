local json = require("@std/json")
local test = require("@std/test")

local githubTypes = require("@root/github/types")
local testing = require("@root/testing")
local trackCheckSnoozes = require("@root/checks/trackCheckSnoozes")
local types = require("@root/types")

type Fetched = githubTypes.Fetched
type PullState = githubTypes.PullState

local function card(id: string, number: number): types.Item
	return testing.task(
		id,
		id,
		"review",
		nil,
		json.object({
			refs = { json.object({ source = "github", kind = "pull", key = `vocksel/orion#{number}` }) },
		})
	)
end

local function pull(number: number, overrides: { [string]: any }): PullState
	local state: { [string]: any } = {
		owner = "vocksel",
		name = "orion",
		number = number,
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
	}

	for key, value in overrides do
		state[key] = value
	end

	return state :: PullState
end

local function fetched(pulls: { PullState }): Fetched
	local byKey: { [string]: PullState } = {}

	for _, entry in pulls do
		byKey[`vocksel/orion#{entry.number}`] = entry
	end

	return { pulls = byKey, checked = {}, authored = {}, viewer = "vocksel", failures = {} }
end

local function snoozeDocs(doc: types.Doc, untilTime: string?)
	local snooze: types.CheckSnooze =
		{ repo = "vocksel/orion", name = "docs", untilTime = untilTime, at = "2026-10-13T00:00:00Z", passed = {} }
	table.insert(doc.settings.checkSnoozes, snooze)
end

test.case("a snooze records each card the job has since passed on and keeps hiding the rest", function(assert)
	local doc = testing.createDoc({ card("a", 1), card("b", 2) })
	snoozeDocs(doc)
	trackCheckSnoozes(
		doc,
		fetched({
			pull(1, { checks = "SUCCESS" }),
			pull(2, { checks = "FAILURE", failedChecks = { { name = "docs", optional = false } }, passedChecks = {} }),
		}),
		"2026-10-13T01:00:00Z"
	)

	assert.eq(#doc.settings.checkSnoozes, 1)
	assert.eq(table.concat(doc.settings.checkSnoozes[1].passed, ","), "a")
end)

test.case("a snooze ends once no card is hiding the job's failure", function(assert)
	local doc = testing.createDoc({ card("a", 1), card("b", 2) })
	snoozeDocs(doc)
	trackCheckSnoozes(
		doc,
		fetched({
			pull(1, { checks = "SUCCESS" }),
			pull(2, {
				checks = "FAILURE",
				failedChecks = { { name = "test", optional = false } },
				passedChecks = { "docs" },
			}),
		}),
		"2026-10-13T01:00:00Z"
	)

	assert.eq(#doc.settings.checkSnoozes, 0)
end)

test.case("a card where the job is still running hasn't passed it yet", function(assert)
	local doc = testing.createDoc({ card("a", 1), card("b", 2) })
	snoozeDocs(doc)
	trackCheckSnoozes(
		doc,
		fetched({
			pull(1, { checks = "PENDING" }),
			pull(2, { checks = "FAILURE", failedChecks = { { name = "docs", optional = false } }, passedChecks = {} }),
		}),
		"2026-10-13T01:00:00Z"
	)

	assert.eq(#doc.settings.checkSnoozes[1].passed, 0)
end)

test.case("a timed snooze ends at its time whatever the job does", function(assert)
	local doc = testing.createDoc({ card("a", 1) })
	snoozeDocs(doc, "2026-10-13T02:00:00Z")
	local failing = fetched({
		pull(1, { checks = "FAILURE", failedChecks = { { name = "docs", optional = false } }, passedChecks = {} }),
	})

	trackCheckSnoozes(doc, failing, "2026-10-13T01:00:00Z")
	assert.eq(#doc.settings.checkSnoozes, 1)

	trackCheckSnoozes(doc, failing, "2026-10-13T02:00:00Z")
	assert.eq(#doc.settings.checkSnoozes, 0)
end)

test.case("a snooze stays when the refresh couldn't fetch every card", function(assert)
	local doc = testing.createDoc({ card("a", 1), card("b", 2) })
	snoozeDocs(doc)
	local partial = fetched({ pull(1, { checks = "SUCCESS" }) })
	partial.failures = { "vocksel/orion#2: gh: HTTP 502" }
	trackCheckSnoozes(doc, partial, "2026-10-13T01:00:00Z")

	assert.eq(#doc.settings.checkSnoozes, 1)
	assert.eq(table.concat(doc.settings.checkSnoozes[1].passed, ","), "a")
end)
