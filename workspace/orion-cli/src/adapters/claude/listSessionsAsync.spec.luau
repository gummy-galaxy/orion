local fs = require("@std/fs")
local test = require("@std/test")

local listSessionsAsync = require("@root/adapters/claude/listSessionsAsync")
local testing = require("@root/testing")
local types = require("@root/types")
local writeFixture = require("@root/adapters/claude/writeFixture")

type CommandRunner = types.CommandRunner
type Source = types.Source

-- Answers `kill -0`, or `tasklist` on Windows, for the fixture's pid while
-- `alive`.
local function runner(alive: boolean): CommandRunner
	return function(argv)
		return testing.result(alive and (argv[1] == "kill" or argv[1] == "tasklist"), '"42"')
	end
end

test.case("a busy process is working, and an idle one leaves you the move", function(assert)
	local dir = testing.directory("claude-live")
	local id = writeFixture(dir, { branch = "agent/fix", stop = "tool_use", status = "busy" })
	local source: Source = { id = "claude", kind = "claude", dir = dir }
	local sessions = listSessionsAsync(source, runner(true), 0, {})

	assert.eq(#sessions, 1)
	assert.eq(sessions[1].id, id)
	assert.eq(sessions[1].cwd, "/work")
	assert.eq(sessions[1].branch, "agent/fix")
	assert.eq(sessions[1].title, "Fix the bug")
	assert.eq(sessions[1].state, "working")
	assert.eq(sessions[1].isLive, true)
	assert.eq(sessions[1].lastMessage, "On it.")

	writeFixture(dir, { branch = "agent/fix", stop = "tool_use", status = "idle" })
	assert.eq(listSessionsAsync(source, runner(true), 0, {})[1].state, "waiting")
	fs.removeDirectory(dir, { recursive = true })
end)

test.case("a session whose process exited mid-turn is your move", function(assert)
	local dir = testing.directory("claude-exited")
	writeFixture(dir, { branch = "agent/fix", stop = "tool_use", status = "busy" })
	local sessions = listSessionsAsync({ id = "claude", kind = "claude", dir = dir } :: Source, runner(false), 0, {})

	assert.eq(sessions[1].state, "waiting")
	assert.eq(sessions[1].isLive, false)
	fs.removeDirectory(dir, { recursive = true })
end)

test.case("with no process records, the transcript decides and liveness is unknown", function(assert)
	local dir = testing.directory("claude-unknown")
	writeFixture(dir, { branch = "agent/fix", stop = "end_turn" })
	local sessions = listSessionsAsync({ id = "claude", kind = "claude", dir = dir } :: Source, runner(true), 0, {})

	assert.eq(sessions[1].state, "waiting")
	assert.eq(sessions[1].isLive, nil)
	assert.eq(sessions[1].title, nil)
	fs.removeDirectory(dir, { recursive = true })
end)

test.case("default branches, old transcripts, and a missing folder list nothing", function(assert)
	local dir = testing.directory("claude-skipped")
	writeFixture(dir, { branch = "main", stop = "end_turn" })
	local source: Source = { id = "claude", kind = "claude", dir = dir }

	assert.eq(#listSessionsAsync(source, runner(true), 0, {}), 0)

	writeFixture(dir, { branch = "agent/fix", stop = "end_turn" })
	assert.eq(#listSessionsAsync(source, runner(true), os.time() + 3600, {}), 0)
	assert.eq(
		#listSessionsAsync({ id = "claude", kind = "claude", dir = `{dir}/missing` } :: Source, runner(true), 0, {}),
		0
	)
	fs.removeDirectory(dir, { recursive = true })
end)

test.case("a transcript is read again only once its size or modification time moves", function(assert)
	local dir = testing.directory("claude-cache")
	writeFixture(dir, { branch = "agent/fix", stop = "end_turn" })
	local source: Source = { id = "claude", kind = "claude", dir = dir }
	local cache = {}

	listSessionsAsync(source, runner(true), 0, cache)

	for _, read in cache do
		read.transcript = table.clone(read.transcript)
		read.transcript.lastMessage = "Remembered"
	end

	assert.eq(listSessionsAsync(source, runner(true), 0, cache)[1].lastMessage, "Remembered")

	writeFixture(dir, { branch = "agent/fixed", stop = "end_turn" })
	assert.eq(listSessionsAsync(source, runner(true), 0, cache)[1].lastMessage, "On it.")
	fs.removeDirectory(dir, { recursive = true })
end)
