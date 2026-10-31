local test = require("@std/test")

local emptyLoop = require("@repository/.lute/lints/emptyLoop")
local testing = require("@cli/testing")

test.case("emptyLoop flags while, for, and repeat loops with nothing in them", function(assert)
	local source = [[
while queue:next() do
end
for index = 1, 3 do
end
for key in pairs(items) do
end
repeat
until done()
]]

	assert.eq(testing.getLintedLines(emptyLoop, source), { 1, 3, 5, 7 })
end)

test.case("emptyLoop allows a loop whose body is a comment or a statement", function(assert)
	local source = [[
while queue:next() do
	-- Drain queued events.
end
for index = 1, 3 do
	print(index)
end
]]

	assert.eq(testing.getLintedLines(emptyLoop, source), {})
end)
