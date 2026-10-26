local test = require("@std/test")

local createSource = require("@root/adapters/claude/createSource")

test.case("claude sources take an absolute data folder and never a command", function(assert)
	local source, command = createSource({})
	assert.eq(source, { id = "claude", kind = "claude" })
	assert.eq(command, nil)
	assert.eq(
		createSource({ dir = { "/tmp/claude" }, id = { "work" } }),
		{ id = "work", kind = "claude", dir = "/tmp/claude" }
	)
	assert.throws(function()
		createSource({ dir = { "relative" } })
	end)
	assert.throws(function()
		createSource({ command = { '["claude"]' } })
	end)
end)
