local test = require("@std/test")

local getNeighborGroup = require("@root/graph/getNeighborGroup")
local testing = require("@root/testing")

test.case("getNeighborGroup takes the group asked for, then the neighbor's group", function(assert)
	local doc = testing.createDoc({
		testing.group("g", "G"),
		testing.group("h", "H"),
		testing.task("a", "A", "todo", "g"),
		testing.task("b", "B", "todo", "h"),
		testing.task("c", "C", "todo"),
	})
	assert.eq(getNeighborGroup(doc, "h", "a", nil), "h")
	assert.eq(getNeighborGroup(doc, nil, "a", "b"), "g")
	assert.eq(getNeighborGroup(doc, nil, nil, "b"), "h")
	assert.eq(getNeighborGroup(doc, nil, "c", nil), nil)
	assert.eq(getNeighborGroup(doc, nil, nil, nil), nil)
end)

test.case("getNeighborGroup refuses a group or neighbor that doesn't exist", function(assert)
	local doc = testing.createDoc({ testing.task("a", "A", "todo") })
	assert.eq(pcall(getNeighborGroup, doc, "missing", nil, nil), false)
	assert.eq(pcall(getNeighborGroup, doc, nil, "missing", nil), false)
end)
