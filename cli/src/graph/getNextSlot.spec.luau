local test = require("@std/test")

local getNextSlot = require("@root/graph/getNextSlot")
local sizes = require("@root/graph/sizes")
local testing = require("@root/testing")

test.case("getNextSlot starts at the origin or below a group's title row", function(assert)
	local doc = testing.createDoc({ testing.group("g", "Group") })
	assert.eq(getNextSlot(testing.createDoc({})), { x = 0, y = 0 })
	assert.eq(getNextSlot(doc, "g"), { x = sizes.GROUP_PADDING, y = sizes.GROUP_HEADER_HEIGHT })
end)

test.case("getNextSlot goes to the right of the rightmost sibling, at the topmost sibling's height", function(assert)
	local first = testing.task("a", "A", "todo", "g")
	first.position = { x = 32, y = 100 }
	local second = testing.task("b", "B", "todo", "g")
	second.position = { x = 300, y = 80 }
	local doc = testing.createDoc({ testing.group("g", "Group"), first, second })
	assert.eq(getNextSlot(doc, "g"), { x = 300 + sizes.TASK_WIDTH + sizes.ITEM_GAP, y = 80 })

	local top = testing.task("c", "C", "todo")
	top.position = { x = 10, y = 20 }
	assert.eq(getNextSlot(testing.createDoc({ top })), { x = 10 + sizes.TASK_WIDTH + sizes.ITEM_GAP * 2, y = 20 })
end)
