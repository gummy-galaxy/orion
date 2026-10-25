local test = require("@std/test")

local types = require("@root/types")
local upsertComment = require("@root/github/upsertComment")

local MARKER = "<!-- orion-test -->"

test.case("upsertComment creates a comment when none carries the marker", function(assert)
	local commands = {} :: { { string } }
	local function run(argv: { string }): types.CommandResult
		table.insert(commands, argv)
		return { ok = true, exitCode = 0, stdout = "", stderr = "" }
	end

	local posted, problem = upsertComment(run, "vocksel/orion", "12", MARKER, `{MARKER}\nhello`)

	assert.eq(posted, true)
	assert.eq(problem, nil)
	assert.eq(#commands, 2)
	assert.eq(table.concat(commands[2], " "), `gh api repos/vocksel/orion/issues/12/comments -f body={MARKER}\nhello`)
end)

test.case("upsertComment replaces the existing comment with the marker", function(assert)
	local commands = {} :: { { string } }
	local function run(argv: { string }): types.CommandResult
		table.insert(commands, argv)
		return { ok = true, exitCode = 0, stdout = "987\n", stderr = "" }
	end

	local posted = upsertComment(run, "vocksel/orion", "12", MARKER, `{MARKER}\nhello`)

	assert.eq(posted, true)
	assert.eq(#commands, 2)
	assert.eq(
		table.concat(commands[2], " "),
		`gh api -X PATCH repos/vocksel/orion/issues/comments/987 -f body={MARKER}\nhello`
	)
end)

test.case("upsertComment reports GitHub's refusal to post", function(assert)
	local function run(argv: { string }): types.CommandResult
		local isPost = argv[4] ~= "--paginate"
		return {
			ok = not isPost,
			exitCode = if isPost then 1 else 0,
			stdout = "",
			stderr = if isPost then "resource not accessible" else "",
		}
	end

	local posted, problem = upsertComment(run, "vocksel/orion", "12", MARKER, `{MARKER}\nhello`)

	assert.eq(posted, false)
	assert.eq(problem, "resource not accessible")
end)
