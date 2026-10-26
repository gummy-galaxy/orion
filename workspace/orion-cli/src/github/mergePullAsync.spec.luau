local test = require("@std/test")

local mergePullAsync = require("@root/github/mergePullAsync")
local types = require("@root/types")

local URL = "https://github.com/vocksel/orion/pull/142"

test.case("mergePullAsync uses the viewer's merge method and pins the head commit", function(assert)
	local commands = {} :: { { string } }
	local function run(argv: { string }): types.CommandResult
		table.insert(commands, argv)
		return { ok = true, exitCode = 0, stdout = if argv[2] == "repo" then "REBASE\n" else "", stderr = "" }
	end

	local merged, problem = mergePullAsync(run, URL, "abc123")

	assert.eq(merged, true)
	assert.eq(problem, nil)
	assert.eq(commands[1][4], "github.com/vocksel/orion")
	assert.eq(table.concat(commands[2], " "), `gh pr merge {URL} --rebase --match-head-commit abc123`)
end)

test.case("mergePullAsync reports GitHub's refusal", function(assert)
	local function run(argv: { string }): types.CommandResult
		local isMerge = argv[2] == "pr"
		return {
			ok = not isMerge,
			exitCode = if isMerge then 1 else 0,
			stdout = "SQUASH",
			stderr = if isMerge then "head changed" else "",
		}
	end

	local merged, problem = mergePullAsync(run, URL, "abc123")

	assert.eq(merged, false)
	assert.eq(problem, "head changed")
end)
