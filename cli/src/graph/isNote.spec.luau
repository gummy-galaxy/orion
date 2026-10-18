local test = require("@std/test")

local isNote = require("@root/graph/isNote")
local testing = require("@root/testing")

test.case("isNote is true only for cards whose kind is note", function(assert)
	assert.eq(isNote(testing.task("n", "Remember", "todo", nil, { itemKind = "note" })), true)
	assert.eq(isNote(testing.task("a", "A", "todo")), false)
	assert.eq(isNote(testing.group("g", "Group")), false)
end)
