local test = require("@std/test")

local geometry = require("@root/geometry")
local getSize = require("@root/graph/getSize")
local testing = require("@root/testing")

test.case("getSize gives cards the app's card size and groups their stored size", function(assert)
	local width, height = getSize(testing.task("a", "A", "todo"))
	assert.eq(width, geometry.TASK_WIDTH)
	assert.eq(height, geometry.TASK_HEIGHT)

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

test.case("getSize takes a card's measured height, or estimates one from its text", function(assert)
	local note = testing.task("n", "a\nb\nc\nd\ne\nf", "todo", nil, { itemKind = "note" })
	local _, estimated = getSize(note)
	assert.eq(estimated, 136)

	note.height = 140
	local _, measured = getSize(note)
	assert.eq(measured, 140)
end)
