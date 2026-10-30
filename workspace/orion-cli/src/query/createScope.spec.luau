local test = require("@std/test")

local createScope = require("@root/query/createScope")
local testing = require("@root/testing")

test.case("every group gets its labels from the top level down", function(assert)
	local scope = createScope(testing.createDoc({
		testing.group("inner", "Inner", "outer"),
		testing.group("outer", "Outer"),
		testing.task("card", "Card", "todo", "inner"),
	}))
	assert.eq(scope.groupPaths.outer, { "Outer" })
	assert.eq(scope.groupPaths.inner, { "Outer", "Inner" })
	assert.eq(scope.groupPaths.card, nil)
	assert.eq(scope.derived.status.card, "ready")
end)

test.case("groups nested in each other stop the walk", function(assert)
	local scope = createScope(testing.createDoc({
		testing.group("a", "A", "b"),
		testing.group("b", "B", "a"),
	}))
	assert.eq(scope.groupPaths.a, { "B", "A" })
	assert.eq(scope.groupPaths.b, { "B" })
end)
