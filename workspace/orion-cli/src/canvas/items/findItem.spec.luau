local test = require("@std/test")

local findItem = require("@root/canvas/items/findItem")
local testing = require("@root/testing")

test.case("findItem returns the item with an id, or nil", function(assert)
	local doc = testing.createDoc({ testing.group("g", "Group"), testing.task("a", "A", "todo", "g") })
	assert.eq(findItem(doc, "a"), doc.nodes[2])
	assert.eq(findItem(doc, "g"), doc.nodes[1])
	assert.eq(findItem(doc, "missing"), nil)
end)
