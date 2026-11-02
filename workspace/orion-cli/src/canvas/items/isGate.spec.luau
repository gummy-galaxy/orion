local test = require("@std/test")

local isGate = require("@root/canvas/items/isGate")
local testing = require("@root/testing")

test.case("isGate is true only for cards whose kind is gate", function(assert)
	assert.eq(isGate(testing.task("g", "Ship", "todo", nil, { type = "gate" })), true)
	assert.eq(isGate(testing.task("a", "A", "todo")), false)
	assert.eq(isGate(testing.group("g", "Group")), false)
end)
