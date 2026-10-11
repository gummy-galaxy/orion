local test = require("@std/test")

local getPullTarget = require("@root/perf/getPullTarget")
local types = require("@root/types")

local HEAD = "0123456789abcdef0123456789abcdef01234567"

test.case("getPullTarget reads the head commit and base branch", function(assert)
	local commands = {} :: { { string } }
	local function run(argv: { string }): types.CommandResult
		table.insert(commands, argv)

		return { ok = true, exitCode = 0, stdout = `{HEAD}\tmain\n`, stderr = "" }
	end

	local target = getPullTarget(run, "vocksel/orion", "240")

	assert.eq(target.headSha, HEAD)
	assert.eq(target.baseRef, "main")
	assert.eq(commands[1][3], "repos/vocksel/orion/pulls/240")
end)

test.case("getPullTarget rejects a pull request number that is not a number", function(assert)
	local function run(): types.CommandResult
		return { ok = true, exitCode = 0, stdout = `{HEAD}\tmain\n`, stderr = "" }
	end

	local ok = pcall(getPullTarget, run, "vocksel/orion", "240; rm -rf")

	assert.eq(ok, false)
end)
