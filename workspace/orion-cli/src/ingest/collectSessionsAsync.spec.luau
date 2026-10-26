local json = require("@std/json")
local test = require("@std/test")

local adapterTypes = require("@root/adapters/types")
local collectSessionsAsync = require("@root/ingest/collectSessionsAsync")
local findRef = require("@root/refs/findRef")
local ingestTypes = require("@root/ingest/types")
local placeRecords = require("@root/ingest/placeRecords")
local testing = require("@root/testing")
local types = require("@root/types")

type AgentVerbs = adapterTypes.AgentVerbs
type Record = adapterTypes.Record
type Session = adapterTypes.Session
type Result = ingestTypes.Result
type Item = types.Item
type Source = types.Source

local NOW = "2026-10-18T12:00:00Z"
local SOURCE: Source = { id = "other", kind = "other-agent" }

-- An agent that isn't Claude Code, to show any adapter with agent verbs
-- plugs in the same way.
local function createAgent(sessions: { Session }): AgentVerbs
	return {
		name = "Other Agent",
		listSessionsAsync = function()
			return sessions
		end,
		readTurnsAsync = function()
			return nil
		end,
	}
end

local function createCard(id: string, repo: string, branch: string): Item
	local card = testing.task(id, id, "active", nil, json.object({ repo = repo }))
	card.data.refs = { json.object({ source = "branch", kind = "branch", key = `{repo}@{branch}` }) } :: json.Array
	return card
end

local function place(doc: types.Doc, records: { Record })
	local result: Result =
		{ source = SOURCE, report = { id = SOURCE.id, added = 0, updated = 0, linked = 0 }, records = records }
	placeRecords(doc, { result })
end

local function session(fields: { [string]: any }): Session
	local value: Session = { id = "s1", cwd = "/work", branch = "agent/fix", state = "waiting", updatedAt = 1760788800 }

	for field, fieldValue in fields do
		(value :: any)[field] = fieldValue
	end

	return value
end

test.case("a session attaches to the card on its branch with its state and last message", function(assert)
	local doc = testing.createDoc({
		createCard("fix", "owner/repo", "agent/fix"),
		createCard("other", "owner/repo", "agent/other"),
	})
	local agent =
		createAgent({ session({ title = "Fix the bug", lastMessage = string.rep("é", 300), isLive = true }) })
	local records = collectSessionsAsync(SOURCE, agent, function(argv)
		assert.eq(argv, { "git", "-C", "/work", "remote", "get-url", "origin" })
		return testing.result(true, "git@github.com:owner/repo.git\n")
	end, { now = NOW, since = "2026-10-04", doc = doc, commands = {} })

	place(doc, records)
	local ref = findRef(doc.nodes[1], "session")

	assert.eq(#doc.nodes, 2)
	assert.eq(findRef(doc.nodes[2], "session"), nil)
	assert.eq(ref and ref.source, "other")
	assert.eq(ref and ref.id, "other-agent:s1")
	assert.eq(ref and ref.key, "Fix the bug")
	assert.eq(ref and ref.sessionState, "waiting")
	assert.eq(ref and ref.stateLabel, "Waiting on you in Other Agent")
	assert.eq(ref and ref.lastMessage, string.rep("é", 280))
	assert.eq(ref and ref.updatedAt, "2025-10-18T12:00:00Z")
	assert.eq(ref and ref.checkedAt, NOW)
	assert.eq(ref and ref.details and ref.details.isLive, true)
	assert.eq(doc.nodes[1].data.label, "fix")
end)

test.case("a session updates its ref in place and never adds a card", function(assert)
	local doc = testing.createDoc({ createCard("fix", "owner/repo", "agent/fix") })
	local context = { now = NOW, since = "2026-10-04", doc = doc, commands = {} }
	local function run()
		return testing.result(true, "https://github.com/owner/repo\n")
	end

	place(doc, collectSessionsAsync(SOURCE, createAgent({ session({ state = "working" }) }), run, context))
	place(doc, collectSessionsAsync(SOURCE, createAgent({ session({ title = "Renamed" }) }), run, context))
	place(
		doc,
		collectSessionsAsync(SOURCE, createAgent({ session({ id = "s2", branch = "agent/none" }) }), run, context)
	)

	local refs = json.asArray(doc.nodes[1].data.refs) or {}
	local ref = findRef(doc.nodes[1], "session")

	assert.eq(#doc.nodes, 1)
	assert.eq(#refs, 2)
	assert.eq(ref and ref.key, "Renamed")
	assert.eq(ref and ref.stateLabel, "Waiting on you in Other Agent")
end)

test.case("a session with no remote attaches only where one card has its branch", function(assert)
	local function collect(doc: types.Doc): { Record }
		return collectSessionsAsync(SOURCE, createAgent({ session({}) }), function()
			return testing.result(false, "")
		end, { now = NOW, since = "2026-10-04", doc = doc, commands = {} })
	end

	local single = testing.createDoc({ createCard("fix", "owner/repo", "agent/fix") })
	place(single, collect(single))
	assert.eq(findRef(single.nodes[1], "session") ~= nil, true)

	local shared =
		testing.createDoc({ createCard("a", "owner/one", "agent/fix"), createCard("b", "owner/two", "agent/fix") })
	place(shared, collect(shared))
	assert.eq(findRef(shared.nodes[1], "session"), nil)
	assert.eq(findRef(shared.nodes[2], "session"), nil)
end)

test.case("a session's own repository skips the git lookup, and one with no branch is left out", function(assert)
	local doc = testing.createDoc({ createCard("fix", "owner/repo", "agent/fix") })
	local branchless = session({ id = "s2" })
	branchless.branch = nil
	local agent = createAgent({ session({ repo = "owner/repo" }), branchless })
	local records = collectSessionsAsync(SOURCE, agent, function()
		error("git shouldn't run")
	end, { now = NOW, since = "2026-10-04", doc = doc, commands = {} })

	assert.eq(#records, 1)
end)
