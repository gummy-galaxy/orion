local json = require("@std/json")
local test = require("@std/test")

local collectChangedAsync = require("@root/github/collectChangedAsync")
local githubTypes = require("@root/github/types")
local testing = require("@root/testing")
local types = require("@root/types")

type PollState = githubTypes.PollState
type Want = githubTypes.Want
type Doc = types.Doc

local LAST_MODIFIED = "Sun, 18 Oct 2026 15:53:33 GMT"
local RECORDED = "2026-10-01T00:00:00Z"
local NOTIFICATIONS: Want = { notifications = true, sweep = false, checks = false }
local SWEEP: Want = { notifications = true, sweep = true, checks = false }
local AUTHORED =
	[[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[],"pageInfo":{"hasNextPage":false}}}}}]]

local function card(id: string, number: number, status: string): types.Item
	return testing.task(id, `Card {number}`, "review", nil, {
		refs = {
			{
				source = "github",
				kind = "pull",
				key = `vocksel/orion#{number}`,
				status = status,
				updatedAt = RECORDED,
			},
		},
	})
end

local function fixture(): (Doc, PollState)
	local doc = testing.createDoc({ card("a", 1, "open"), card("b", 2, "open"), card("m", 3, "merged") })
	doc.github = json.object({ viewer = "vocksel", unplaced = {} })
	return doc, { lastModified = { ["github.com"] = "Sat, 17 Oct 2026 01:02:03 GMT" }, interval = 60 }
end

-- Answers notifications with `notifications` and records every GraphQL query by what it asks for.
local function createRunner(notifications: string?, sweep: string?, checks: string?)
	local queries: { [string]: { string } } = { full = {}, sweep = {}, authored = {}, checks = {} }

	local function run(argv: { string }): types.CommandResult
		if argv[3] == "--include" then
			if notifications then
				return testing.result(true, `HTTP/2.0 200 OK\nLast-Modified: {LAST_MODIFIED}\n\n{notifications}`)
			end

			return testing.result(
				false,
				`HTTP/2.0 304 Not Modified\nLast-Modified: {LAST_MODIFIED}\n\n`,
				"gh: HTTP 304"
			)
		end

		local query = argv[#argv]

		if query:find("pullRequests(first:", 1, true) then
			table.insert(queries.authored, query)
			return testing.result(true, AUTHORED)
		elseif query:find("{ updatedAt }", 1, true) then
			table.insert(queries.sweep, query)
			return testing.result(true, sweep or [[{"data":{}}]])
		elseif query:find("{ number state url headRefOid commits", 1, true) then
			table.insert(queries.checks, query)
			return testing.result(true, checks or [[{"data":{}}]])
		end

		table.insert(queries.full, query)
		return testing.result(true, [[{"data":{"p1":{"pullRequest":{"number":2,"state":"OPEN","url":"u2"}}}}]])
	end

	return run, queries
end

test.case("a quiet poll fetches nothing and keeps the time it sent", function(assert)
	local doc, poll = fixture()
	local run, queries = createRunner(nil)
	local changes = collectChangedAsync(doc, run, poll, NOTIFICATIONS)

	assert.eq(changes.fetched, nil)
	assert.eq(#changes.failures, 0)
	assert.eq(#queries.full + #queries.sweep + #queries.authored, 0)
	assert.eq(poll.lastModified["github.com"], "Sat, 17 Oct 2026 01:02:03 GMT")
end)

test.case("notifications refetch only the cards they name", function(assert)
	local doc, poll = fixture()
	local run, queries = createRunner([=[[
		{"subject":{"type":"PullRequest","url":"https://api.github.com/repos/vocksel/orion/pulls/2"}},
		{"subject":{"type":"PullRequest","url":"https://api.github.com/repos/vocksel/orion/pulls/99"}}
	]]=])
	local changes = collectChangedAsync(doc, run, poll, NOTIFICATIONS)
	assert.neq(changes.fetched, nil)
	local fetched = changes.fetched :: githubTypes.Fetched

	assert.eq(changes.refetched, 1)
	assert.eq(#queries.full, 1)
	assert.strContains(queries.full[1], "number: 2)")
	assert.eq(queries.full[1]:find("number: 1)", 1, true), nil)
	assert.eq(#queries.authored, 0)
	assert.eq(#queries.sweep, 0)
	assert.eq(fetched.authored, nil)
	assert.eq(fetched.viewer, "vocksel")
	assert.neq(fetched.pulls["vocksel/orion#2"], nil)
end)

test.case("a sweep refetches the open cards whose updatedAt moved", function(assert)
	local doc, poll = fixture()
	local run, queries = createRunner(
		nil,
		`\{"data":\{"p1":\{"pullRequest":\{"updatedAt":"{RECORDED}"}},"p2":\{"pullRequest":\{"updatedAt":"2026-10-18T00:00:00Z"}}}}`
	)
	local changes = collectChangedAsync(doc, run, poll, SWEEP)

	assert.neq(changes.fetched, nil)
	assert.eq(#queries.sweep, 1)
	assert.eq(queries.sweep[1]:find("number: 3)", 1, true), nil)
	assert.eq(#queries.authored, 1)
	assert.eq(#queries.full, 1)
	assert.strContains(queries.full[1], "number: 2)")
	assert.eq(queries.full[1]:find("number: 1)", 1, true), nil)
end)

test.case("a sweep that finds nothing new writes nothing", function(assert)
	local doc, poll = fixture()
	local run, queries = createRunner(
		nil,
		`\{"data":\{"p1":\{"pullRequest":\{"updatedAt":"{RECORDED}"}},"p2":\{"pullRequest":\{"updatedAt":"{RECORDED}"}}}}`
	)
	local changes = collectChangedAsync(doc, run, poll, SWEEP)

	assert.eq(changes.fetched, nil)
	assert.eq(changes.refetched, 0)
	assert.eq(#queries.authored, 1)
	assert.eq(#queries.full, 0)
end)

test.case("a sweep of chosen cards compares only theirs and lists nothing", function(assert)
	local doc, poll = fixture()
	local run, queries = createRunner(nil, [[{"data":{"p1":{"pullRequest":{"updatedAt":"2026-10-18T00:00:00Z"}}}}]])
	local want: Want = { notifications = false, sweep = false, checks = false, sweepCards = { b = true, m = true } }
	local changes = collectChangedAsync(doc, run, poll, want)

	assert.neq(changes.fetched, nil)
	assert.eq(changes.refetched, 1)
	assert.eq(#queries.sweep, 1)
	assert.strContains(queries.sweep[1], "number: 2)")
	assert.eq(queries.sweep[1]:find("number: 1)", 1, true), nil)
	assert.eq(queries.sweep[1]:find("number: 3)", 1, true), nil)
	assert.eq(#queries.authored, 0)
	assert.strContains(queries.full[1], "number: 2)")
end)

test.case("a sweep of chosen cards with none on the canvas fetches nothing", function(assert)
	local doc, poll = fixture()
	local run, queries = createRunner(nil)
	local want: Want = { notifications = false, sweep = false, checks = false, sweepCards = { gone = true } }
	local changes = collectChangedAsync(doc, run, poll, want)

	assert.eq(changes.fetched, nil)
	assert.eq(#queries.full + #queries.sweep + #queries.authored, 0)
end)

local function pendingCard(id: string, number: number, finished: number): types.Item
	return testing.task(id, `Card {number}`, "review", nil, {
		refs = {
			{
				source = "github",
				kind = "pull",
				key = `vocksel/orion#{number}`,
				status = "open",
				updatedAt = RECORDED,
				checks = json.object({ state = "pending" }),
				details = json.object({
					checks = "PENDING",
					checkProgress = "running",
					checkCounts = json.object({ total = 2, finished = finished, failed = 0 }),
					head = "abc",
				}),
			},
		},
	})
end

local function checksResponse(finished: number): string
	local states = if finished == 2
		then [[{"state":"SUCCESS","count":2}]]
		else `\{"state":"SUCCESS","count":{finished}},\{"state":"IN_PROGRESS","count":{2 - finished}}`
	return `\{"data":\{"p1":\{"pullRequest":\{"number":4,"state":"OPEN","url":"u4","headRefOid":"abc","commits":\{"nodes":[\{"commit":\{"statusCheckRollup":\{"state":"PENDING","contexts":\{"checkRunCountsByState":[{states}],"statusContextCountsByState":[]}}}}]}}}}}`
end

test.case("a checks pass refetches only pending cards whose checks moved", function(assert)
	local doc = testing.createDoc({ card("a", 1, "open"), pendingCard("p", 4, 1) })
	doc.github = json.object({ viewer = "vocksel", unplaced = {} })
	local poll = { lastModified = {}, interval = 60 }
	local want: Want = { notifications = false, sweep = false, checks = true }

	local run, queries = createRunner(nil, nil, checksResponse(1))
	local changes = collectChangedAsync(doc, run, poll, want)
	assert.eq(changes.fetched, nil)
	assert.eq(#queries.checks, 1)
	assert.strContains(queries.checks[1], "number: 4)")
	assert.eq(queries.checks[1]:find("number: 1)", 1, true), nil)
	assert.eq(#queries.full, 0)

	run, queries = createRunner(nil, nil, checksResponse(2))
	changes = collectChangedAsync(doc, run, poll, want)
	assert.neq(changes.fetched, nil)
	assert.eq(changes.refetched, 1)
	assert.strContains(queries.full[1], "number: 4)")
end)
