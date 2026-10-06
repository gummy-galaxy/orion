local test = require("@std/test")

local parent = require("@root/server/parent")
local testing = require("@root/testing")

test.case("parent liveness checks the requested pid through the command runner", function(assert)
	local calls = 0
	local function run(argv: { string })
		calls += 1
		assert.eq(argv[1], "kill")
		assert.eq(argv[2], "-0")
		assert.eq(argv[3], "1234")
		return testing.result(calls == 1, "")
	end

	assert.eq(parent.isProcessAlive(1234, run), true)
	assert.eq(parent.isProcessAlive(1234, run), false)
	assert.eq(calls, 2)
end)
