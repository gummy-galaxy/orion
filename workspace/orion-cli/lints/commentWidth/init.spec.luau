local syntax = require("@std/syntax")
local test = require("@std/test")

local commentWidth = require("@repo/lints/commentWidth")
local testing = require("@root/testing")

local LONG = "one two three four five six seven eight nine ten eleven twelve thirteen fourteen"

-- The fixes `lute lint --auto-fix` would make, in order.
local function getFixes(source: string): { string }
	local violations = commentWidth.lint(syntax.parse(source).root, nil, { globals = {}, options = {} })
	local fixes: { string } = {}

	for _, violation in violations do
		table.insert(fixes, if violation.suggestedfix then violation.suggestedfix.fix else "")
	end

	return fixes
end

test.case("commentWidth rewraps a run of comments that runs past 80 columns", function(assert)
	local source = `\t-- {LONG}\n\t-- fifteen\nlocal value = 1\n`

	assert.eq(testing.getLintedLines(commentWidth, source), { 1 })
	assert.eq(getFixes(source), {
		"-- one two three four five six seven eight nine ten eleven twelve thirteen\n\t-- fourteen fifteen",
	})
end)

test.case("commentWidth counts a tab as four columns", function(assert)
	local fits = "-- one two three four five six seven eight nine ten eleven twelve thirteen"
	local source = `{fits}\n\t\t{fits}\nlocal value = 1\n`

	assert.eq(testing.getLintedLines(commentWidth, source), { 2 })
end)

test.case("commentWidth keeps blank lines and indented lines out of the wrap", function(assert)
	local source = `-- {LONG}\n--\n--   keep  this\nlocal value = 1\n`

	assert.eq(getFixes(source), {
		"-- one two three four five six seven eight nine ten eleven twelve thirteen\n-- fourteen",
	})
end)

test.case("commentWidth rewraps the inside of a block comment", function(assert)
	local source = `--[[\n\t{LONG} fifteen\n\n\tkept\n]]\nlocal value = 1\n`

	assert.eq(getFixes(source), {
		"--[[\n\tone two three four five six seven eight nine ten eleven twelve thirteen\n\tfourteen fifteen\n\n\tkept\n]]",
	})
end)

test.case("commentWidth reports a comment after code without a fix", function(assert)
	local source = `local value = 1 -- {LONG}\n`

	assert.eq(testing.getLintedLines(commentWidth, source), { 1 })
	assert.eq(getFixes(source), { "" })
end)

test.case("commentWidth allows comments that fit or only overflow on one long word", function(assert)
	local url = `https://example.com/{string.rep("a", 80)}`
	local source = `-- Short.\nlocal value = 1\n-- See\n-- {url}\nreturn value\n`

	assert.eq(testing.getLintedLines(commentWidth, source), {})
end)
