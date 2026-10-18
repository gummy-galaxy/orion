local test = require("@std/test")

local getLabel = require("@root/graph/getLabel")
local testing = require("@root/testing")

test.case("getLabel reads an item's label, or an empty string without one", function(assert)
	assert.eq(getLabel(testing.task("a", "Ship it", "todo")), "Ship it")
	assert.eq(getLabel(testing.task("b", "B", "todo", nil, { label = 12 })), "")
end)
