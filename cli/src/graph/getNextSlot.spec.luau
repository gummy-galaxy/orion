local test = require("@std/test")

local geometry = require("@root/geometry")
local getNextSlot = require("@root/graph/getNextSlot")
local testing = require("@root/testing")

test.case("getNextSlot starts at the origin or below a group's title row", function(assert)
	local doc = testing.createDoc({ testing.group("g", "Group") })
	assert.eq(getNextSlot(testing.createDoc({})), { x = 0, y = 0 })
	assert.eq(getNextSlot(doc, "g"), { x = geometry.GROUP_PADDING, y = geometry.GROUP_HEADER_HEIGHT })
end)

test.case("getNextSlot goes to the right of the rightmost sibling, at the topmost sibling's height", function(assert)
	local first = testing.task("a", "A", "todo", "g")
	first.position = { x = 32, y = 100 }
	local second = testing.task("b", "B", "todo", "g")
	second.position = { x = 300, y = 80 }
	local doc = testing.createDoc({ testing.group("g", "Group"), first, second })
	assert.eq(getNextSlot(doc, "g"), { x = 300 + geometry.TASK_WIDTH + geometry.GAP.inner.component, y = 80 })

	local top = testing.task("c", "C", "todo")
	top.position = { x = 10, y = 20 }
	assert.eq(
		getNextSlot(testing.createDoc({ top })),
		{ x = 10 + geometry.TASK_WIDTH + geometry.GAP.top.component, y = 20 }
	)
end)
