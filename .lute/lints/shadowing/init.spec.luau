local test = require("@std/test")

local shadowing = require("@repository/.lute/lints/shadowing")
local testing = require("@workspace/orion-cli/src/testing")

test.case("shadowing flags a callback parameter that reuses the local it's assigned to", function(assert)
	local source = [[
local doc = runTransaction(dir, function(doc)
	return doc
end)
]]

	assert.eq(testing.getLintedLines(shadowing, source), { 1 })
end)

test.case("shadowing flags loop variables and nested locals that reuse an outer name", function(assert)
	local source = [[
local function count(total)
	for total = 1, 2 do
		local total = 3
	end
end
]]

	assert.eq(testing.getLintedLines(shadowing, source), { 2, 3 })
end)

test.case("shadowing allows sibling scopes and names that start with an underscore", function(assert)
	local source = [[
for index in first do
end
for index in second do
end
local _unused = 1
local function ignore(_unused) end
]]

	assert.eq(testing.getLintedLines(shadowing, source), {})
end)
