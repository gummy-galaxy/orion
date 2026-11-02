local test = require("@std/test")

local isComponent = require("@root/canvas/items/isComponent")
local testing = require("@root/testing")

test.case("isComponent is true only for cards whose kind is component", function(assert)
	assert.eq(isComponent(testing.task("api", "API", "todo", nil, { type = "component" })), true)
	assert.eq(isComponent(testing.task("a", "A", "todo")), false)
	assert.eq(isComponent(testing.group("g", "Group")), false)
end)
