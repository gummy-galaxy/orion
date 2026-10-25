local test = require("@std/test")

local geometry = require("@root/geometry")
local overlapsSibling = require("@root/graph/overlapsSibling")
local testing = require("@root/testing")

local width = geometry.TASK_WIDTH
local height = geometry.TASK_HEIGHT
local gap = geometry.GAP.inner

local function setup()
	local card = testing.task("a", "A", "todo", "g")
	card.position = { x = 100, y = 100 }
	local stranger = testing.task("b", "B", "todo")
	stranger.position = { x = 400, y = 100 }
	return testing.createDoc({ testing.group("g", "G"), card, stranger })
end

test.case("overlapsSibling counts a box closer than a row gap to a sibling", function(assert)
	local doc = setup()
	assert.eq(overlapsSibling(doc, "g", { x = 100, y = 100 + height + gap.y - 1 }, width, height), true)
	assert.eq(overlapsSibling(doc, "g", { x = 100, y = 100 + height + gap.y }, width, height), false)
	assert.eq(overlapsSibling(doc, "g", { x = 100 + width + gap.y, y = 100 }, width, height), false)
end)

test.case("overlapsSibling only checks the parent's children and leaves out skipped ids", function(assert)
	local doc = setup()
	assert.eq(overlapsSibling(doc, "g", { x = 400, y = 100 }, width, height), false)
	assert.eq(overlapsSibling(doc, "g", { x = 100, y = 100 }, width, height, { a = true }), false)
end)
