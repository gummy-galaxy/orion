local test = require("@std/test")

local getSize = require("@root/graph/getSize")
local sizes = require("@root/graph/sizes")
local testing = require("@root/testing")

test.case("getSize gives cards the app's card size and groups their stored size", function(assert)
	local width, height = getSize(testing.task("a", "A", "todo"))
	assert.eq(width, sizes.TASK_WIDTH)
	assert.eq(height, sizes.TASK_HEIGHT)

	local groupWidth, groupHeight = getSize(testing.group("g", "Group"))
	assert.eq(groupWidth, 400)
	assert.eq(groupHeight, 200)
end)

test.case("getSize falls back to a default for groups without a stored size", function(assert)
	local group = testing.group("g", "Group")
	group.width = nil
	group.height = nil
	local width, height = getSize(group)
	assert.eq(width, 320)
	assert.eq(height, 200)
end)
