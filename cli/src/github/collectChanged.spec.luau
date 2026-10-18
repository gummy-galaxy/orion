local json = require("@std/json")
local test = require("@std/test")

local collectChanged = require("@root/github/collectChanged")
local githubTypes = require("@root/github/types")
local testing = require("@root/testing")
local types = require("@root/types")

type PollState = githubTypes.PollState
type Doc = types.Doc

local LAST_MODIFIED = "Sun, 18 Oct 2026 15:53:33 GMT"
local RECORDED = "2026-10-01T00:00:00Z"
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
local function createRunner(notifications: string?, sweep: string?)
	local queries: { [string]: { string } } = { full = {}, sweep = {}, authored = {} }

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
		end

		table.insert(queries.full, query)
		return testing.result(true, [[{"data":{"p1":{"pullRequest":{"number":2,"state":"OPEN","url":"u2"}}}}]])
	end

	return run, queries
end

test.case("a quiet poll fetches nothing and keeps the time it sent", function(assert)
	local doc, poll = fixture()
	local run, queries = createRunner(nil)
	local changes = collectChanged(doc, run, poll, false)

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
	local changes = collectChanged(doc, run, poll, false)
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
	local changes = collectChanged(doc, run, poll, true)

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
	local changes = collectChanged(doc, run, poll, true)

	assert.eq(changes.fetched, nil)
	assert.eq(changes.refetched, 0)
	assert.eq(#queries.authored, 1)
	assert.eq(#queries.full, 0)
end)
