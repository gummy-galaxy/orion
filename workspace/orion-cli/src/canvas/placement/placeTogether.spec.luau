local test = require("@std/test")

local geometry = require("@root/geometry")
local placeTogether = require("@root/canvas/placement/placeTogether")
local testing = require("@root/testing")

local pitch = geometry.TASK_WIDTH + geometry.GAP.inner.x

test.case("placeTogether lays a chain added together out in a row", function(assert)
	local group = testing.group("g", "G")
	group.width = 2000
	local first = testing.task("a", "A", "todo", "g")
	local second = testing.task("b", "B", "todo", "g")
	local third = testing.task("c", "C", "todo", "g")
	-- Where each landed before its links were known.
	second.position = { x = 900, y = 600 }
	third.position = { x = 32, y = 78 }
	local doc = testing.createDoc({ group, first, second, third }, { { "a", "b" }, { "b", "c" } })
	placeTogether(doc, { "a", "b", "c", "gone" })
	assert.eq(first.position, { x = geometry.GROUP_PADDING, y = geometry.GROUP_HEADER_HEIGHT })
	assert.eq(second.position, { x = geometry.GROUP_PADDING + pitch, y = geometry.GROUP_HEADER_HEIGHT })
	assert.eq(third.position, { x = geometry.GROUP_PADDING + pitch * 2, y = geometry.GROUP_HEADER_HEIGHT })
end)
