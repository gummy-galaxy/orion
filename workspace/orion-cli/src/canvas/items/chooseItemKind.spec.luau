local test = require("@std/test")

local chooseItemKind = require("@root/canvas/items/chooseItemKind")

test.case("chooseItemKind keeps gates and components and reads the rest from the repository and pull", function(assert)
	assert.eq(chooseItemKind("vocksel/orion", 1, "gate"), "gate")
	assert.eq(chooseItemKind(nil, nil, "component"), "component")
	assert.eq(chooseItemKind("vocksel/orion", 1, "step"), "pr")
	assert.eq(chooseItemKind("vocksel/orion", nil, nil), "placeholder")
	assert.eq(chooseItemKind(nil, 1, nil), "step")
	assert.eq(chooseItemKind(nil, nil, nil), "step")
end)
