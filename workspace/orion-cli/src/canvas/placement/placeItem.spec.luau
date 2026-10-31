local test = require("@std/test")

local placeItem = require("@root/canvas/placement/placeItem")
local testing = require("@root/testing")

test.case("placeItem sets an item's position", function(assert)
	local doc = testing.createDoc({ testing.task("a", "A", "todo") })
	local item = placeItem(doc, "a", { x = 40, y = 80 })
	assert.eq(item, doc.nodes[1])
	assert.eq(item.position, { x = 40, y = 80 })
end)
