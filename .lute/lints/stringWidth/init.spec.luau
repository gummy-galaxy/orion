local test = require("@std/test")

local stringWidth = require("@repository/.lute/lints/stringWidth")
local testing = require("@cli/testing")

local LONG_TEXT = string.rep("word ", 24)

test.case("stringWidth flags a line holding a string wider than 120 columns", function(assert)
	local source = `local short = "fits"\nlocal long = "{LONG_TEXT}"\nlocal interpolated = \`\{short} {LONG_TEXT}\`\n`

	assert.eq(testing.getLintedLines(stringWidth, source), { 2, 3 })
end)

test.case("stringWidth counts a tab as four columns", function(assert)
	local text = string.rep("a", 100)
	local source = `do\n\t\t\tlocal value = "{text}"\nend\ndo\n\tlocal value = "{text}"\nend\n`

	assert.eq(testing.getLintedLines(stringWidth, source), { 2 })
end)

test.case("stringWidth allows a long string split across lines", function(assert)
	local source = `local text = "{LONG_TEXT:sub(1, 60)}"\n\t.. "{LONG_TEXT:sub(61)}"\n`

	assert.eq(testing.getLintedLines(stringWidth, source), {})
end)
