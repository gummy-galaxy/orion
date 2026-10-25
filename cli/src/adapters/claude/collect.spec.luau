local fs = require("@std/fs")
local json = require("@std/json")
local test = require("@std/test")

local collect = require("@root/adapters/claude/collect")
local placeRecords = require("@root/ingest/placeRecords")
local testing = require("@root/testing")
local types = require("@root/types")

type Source = types.Source

local NOW = "2026-10-18T12:00:00Z"
local SESSION = "0b6c3a9e-1111-4222-8333-944455556666"

local function writeFixture(dir: string, branch: string, stop: string)
	fs.createDirectory(`{dir}/projects/-work`, { makeParents = true })
	fs.createDirectory(`{dir}/sessions`, { makeParents = true })
	fs.writeStringToFile(
		`{dir}/projects/-work/{SESSION}.jsonl`,
		`\{"type":"user","gitBranch":"{branch}","cwd":"/work","message":\{"content":"Go"}}\n`
			.. `\{"type":"assistant","gitBranch":"{branch}","cwd":"/work","message":\{"stop_reason":"{stop}","content":[\{"type":"text","text":"On it."},\{"type":"tool_use"}]}}\n`
	)
	fs.writeStringToFile(
		`{dir}/sessions/42.json`,
		json.serialize(json.object({ pid = 42, sessionId = SESSION, status = "idle", name = "Fix the bug" }))
	)
	-- Key files sit beside the records and must never be read.
	fs.writeStringToFile(`{dir}/sessions/42.secret.key`, "not json")
end

test.case("sessions attach to the card on their branch with their state, and never add cards", function(assert)
	local dir = testing.directory("claude")
	writeFixture(dir, "agent/fix", "tool_use")
	local card = testing.task("card", "Fix", "active", nil, json.object({ repo = "owner/repo" }))
	card.data.refs = { json.object({ source = "branch", kind = "branch", key = "owner/repo@agent/fix" }) } :: json.Array
	local doc = testing.createDoc({ card })
	local source: Source = { id = "claude", kind = "claude", dir = dir }
	local records = collect(source, function(argv)
		if argv[1] == "kill" then
			return testing.result(true, "")
		end

		return testing.result(true, "git@github.com:owner/repo.git\n")
	end, { now = NOW, since = "2026-10-04", doc = doc, commands = {} })

	assert.eq(#records, 1)
	assert.eq(records[1].ref.key, `claude:{SESSION}`)
	assert.eq(records[1].ref.sessionState, "waiting")
	assert.eq(records[1].ref.lastMessage, "On it.")
	assert.eq(records[1].label, "Fix the bug")

	placeRecords(
		doc,
		{ { source = source, report = { id = "claude", added = 0, updated = 0, linked = 0 }, records = records } } :: any
	)
	local refs = json.asArray(doc.nodes[1].data.refs) or {}
	assert.eq(#doc.nodes, 1)
	assert.eq(#refs, 2)
	local sessionRef = json.asObject(refs[2])
	assert.eq(sessionRef and sessionRef.kind, "session")
	fs.removeDirectory(dir, { recursive = true })
end)

test.case("a session with no card on its branch is left for triage", function(assert)
	local dir = testing.directory("claude-unmatched")
	writeFixture(dir, "agent/other", "end_turn")
	local doc = testing.createDoc({})
	local source: Source = { id = "claude", kind = "claude", dir = dir }
	local records = collect(source, function(argv)
		return testing.result(argv[1] == "kill", "")
	end, { now = NOW, since = "2026-10-04", doc = doc, commands = {} })

	placeRecords(
		doc,
		{ { source = source, report = { id = "claude", added = 0, updated = 0, linked = 0 }, records = records } } :: any
	)
	assert.eq(#doc.nodes, 0)
	fs.removeDirectory(dir, { recursive = true })
end)
