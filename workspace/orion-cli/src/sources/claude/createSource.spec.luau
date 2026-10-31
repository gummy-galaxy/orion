local system = require("@std/system")
local test = require("@std/test")

local createSource = require("@root/sources/claude/createSource")

-- An absolute folder on the platform running the spec, since createSource
-- checks --dir with the host's rules.
local DIR = if system.win32 then "C:/claude" else "/tmp/claude"

test.case("claude sources take an absolute data folder and never a command", function(assert)
	local source, command = createSource({})
	assert.eq(source, { id = "claude", kind = "claude" })
	assert.eq(command, nil)
	assert.eq(createSource({ dir = { DIR }, id = { "work" } }), { id = "work", kind = "claude", dir = DIR })
	assert.throws(function()
		createSource({ dir = { "relative" } })
	end)
	assert.throws(function()
		createSource({ command = { '["claude"]' } })
	end)
end)
