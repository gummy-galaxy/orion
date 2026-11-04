local test = require("@std/test")

local ifSameThenElse = require("@repository/.lute/lints/ifSameThenElse")
local testing = require("@workspace/orion-cli/src/testing")

test.case("ifSameThenElse flags a branch with the same body as an earlier one", function(assert)
	local source = [[
if first then
	value = nil
elseif second then
	value = true
else
	-- Spacing and comments don't matter.
	value  =  nil
end
]]

	assert.eq(testing.getLintedLines(ifSameThenElse, source), { 5 })
end)

test.case("ifSameThenElse allows branches with different bodies", function(assert)
	local source = [[
if first then
	value = nil
elseif second then
	value = false
end
]]

	assert.eq(testing.getLintedLines(ifSameThenElse, source), {})
end)
