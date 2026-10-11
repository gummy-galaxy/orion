local test = require("@std/test")

local findPerfComment = require("@root/perf/findPerfComment")
local perfComment = require("@root/perf/perfComment")
local types = require("@root/types")

test.case("findPerfComment returns the bot's perf comment with its body", function(assert)
	local commands = {} :: { { string } }
	local function run(argv: { string }): types.CommandResult
		table.insert(commands, argv)

		return {
			ok = true,
			exitCode = 0,
			stdout = `[12,"ignored"]\n[34,"{perfComment.MARKER}\\n## Perf\\n"]\n`,
			stderr = "",
		}
	end

	local found = findPerfComment(run, "vocksel/orion", "240")

	assert.eq(found ~= nil, true)
	assert.eq((found :: { id: string, body: string }).id, "12")
	assert.eq(commands[1][3], "repos/vocksel/orion/issues/240/comments")
end)

test.case("findPerfComment returns nil when the pull request has no perf comment", function(assert)
	local function run(): types.CommandResult
		return { ok = true, exitCode = 0, stdout = "", stderr = "" }
	end

	assert.eq(findPerfComment(run, "vocksel/orion", "240"), nil)
end)

test.case("findPerfComment errors when gh fails", function(assert)
	local function run(): types.CommandResult
		return { ok = false, exitCode = 1, stdout = "", stderr = "not found" }
	end

	local ok, message = pcall(findPerfComment, run, "vocksel/orion", "240")

	assert.eq(ok, false)
	assert.eq(string.find(tostring(message), "not found", 1, true) ~= nil, true)
end)
