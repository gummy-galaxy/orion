local test = require("@std/test")

local isProcessAlive = require("@root/server/isProcessAlive")
local testing = require("@root/testing")

test.case("isProcessAlive checks the pid with kill -0", function(assert)
	local calls = 0

	local function run(argv: { string })
		calls += 1
		assert.eq(table.concat(argv, " "), "kill -0 1234")
		return testing.result(calls == 1, "")
	end

	assert.eq(isProcessAlive(1234, run), true)
	assert.eq(isProcessAlive(1234, run), false)
end)
