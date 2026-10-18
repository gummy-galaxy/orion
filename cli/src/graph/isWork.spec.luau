local test = require("@std/test")

local isWork = require("@root/graph/isWork")
local testing = require("@root/testing")

test.case("isWork counts steps and gates, but not notes, components, or groups", function(assert)
	assert.eq(isWork(testing.task("a", "A", "todo")), true)
	assert.eq(isWork(testing.task("g", "Ship", "todo", nil, { itemKind = "gate" })), true)
	assert.eq(isWork(testing.task("n", "Remember", "todo", nil, { itemKind = "note" })), false)
	assert.eq(isWork(testing.task("api", "API", "todo", nil, { itemKind = "component" })), false)
	assert.eq(isWork(testing.group("g", "Group")), false)
end)
