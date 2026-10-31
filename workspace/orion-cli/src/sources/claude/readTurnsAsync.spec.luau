local fs = require("@std/fs")
local test = require("@std/test")

local readTurnsAsync = require("@root/sources/claude/readTurnsAsync")
local testing = require("@root/testing")
local types = require("@root/types")

type Source = types.Source

test.case("a session's last turns read from its transcript, and an unknown id reads nothing", function(assert)
	local dir = testing.directory("claude-turns")
	local id = testing.writeClaudeFixture(dir, { branch = "agent/fix", stop = "end_turn" })
	local source: Source = { id = "claude", kind = "claude", dir = dir }
	local run = function()
		return testing.result(false, "")
	end
	local turns = readTurnsAsync(source, run, id, 1)

	assert.eq(turns and #turns, 1)
	assert.eq(turns and turns[1].text, "On it.")
	assert.eq(#(readTurnsAsync(source, run, id, 10) or {}), 2)
	assert.eq(readTurnsAsync(source, run, "0000", 10), nil)
	assert.eq(readTurnsAsync(source, run, "../escape", 10), nil)
	fs.removeDirectory(dir, { recursive = true })
end)
