local test = require("@std/test")

local getParentProcessId = require("@root/server/getParentPid")
local testing = require("@root/testing")

test.case("getParentPid reads the parent from ps", function(assert)
	local function run(argv: { string })
		assert.eq(table.concat(argv, " "), "ps -o ppid= -p 42")
		return testing.result(true, "  7\n")
	end

	assert.eq(getParentProcessId(run, 42), 7)
end)

test.case("getParentPid returns nil when ps fails", function(assert)
	local function run(_argv: { string })
		return testing.result(false, "")
	end

	assert.eq(getParentProcessId(run, 42), nil)
end)
