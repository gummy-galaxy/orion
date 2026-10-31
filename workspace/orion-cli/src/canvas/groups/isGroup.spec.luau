local test = require("@std/test")

local isGroup = require("@root/canvas/groups/isGroup")
local testing = require("@root/testing")

test.case("isGroup is true for groups and false for cards", function(assert)
	assert.eq(isGroup(testing.group("g", "Group")), true)
	assert.eq(isGroup(testing.task("a", "A", "todo")), false)
end)
