local test = require("@std/test")

local freeSpotBelow = require("@root/canvas/placement/freeSpotBelow")
local geometry = require("@root/geometry")
local testing = require("@root/testing")

local width = geometry.TASK_WIDTH
local height = geometry.TASK_HEIGHT
local step = height + geometry.GAP.inner.y

test.case("freeSpotBelow keeps a free spot and steps down a row past taken ones", function(assert)
	local first = testing.task("a", "A", "todo", "g")
	first.position = { x = 32, y = 78 }
	local second = testing.task("b", "B", "todo", "g")
	second.position = { x = 32, y = 78 + step }
	local doc = testing.createDoc({ testing.group("g", "G"), first, second })
	assert.eq(freeSpotBelow(doc, "g", { x = 400, y = 78 }, width, height), { x = 400, y = 78 })
	assert.eq(freeSpotBelow(doc, "g", { x = 32, y = 78 }, width, height), { x = 32, y = 78 + step * 2 })
	assert.eq(freeSpotBelow(doc, "g", { x = 32, y = 78 }, width, height, { b = true }), { x = 32, y = 78 + step })
end)
