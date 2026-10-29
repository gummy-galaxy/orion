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

	assert.eq(isProcessAlive(1234, run, false), true)
	assert.eq(isProcessAlive(1234, run, false), false)
end)

test.case("isProcessAlive looks for the pid in tasklist's output on Windows", function(assert)
	local listed = '"lute.exe","1234","Console","1","12,345 K"\n'
	local missing = "INFO: No tasks are running which match the specified criteria.\n"
	local outputs = { listed, missing }
	local calls = 0

	local function run(argv: { string })
		calls += 1
		assert.eq(table.concat(argv, " "), "tasklist /FI PID eq 1234 /FO CSV /NH")
		return testing.result(true, outputs[calls])
	end

	assert.eq(isProcessAlive(1234, run, true), true)
	assert.eq(isProcessAlive(1234, run, true), false)
end)
