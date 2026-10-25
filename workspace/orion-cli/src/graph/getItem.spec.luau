local test = require("@std/test")

local getItem = require("@root/graph/getItem")
local testing = require("@root/testing")

test.case("getItem returns the item with an id and refuses a missing one", function(assert)
	local doc = testing.createDoc({ testing.task("a", "A", "todo") })
	assert.eq(getItem(doc, "a"), doc.nodes[1])
	assert.throwsWith('no item or group with id "missing"', function()
		getItem(doc, "missing")
	end)
end)
