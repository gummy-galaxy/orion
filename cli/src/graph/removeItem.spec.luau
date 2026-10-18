local test = require("@std/test")

local findItem = require("@root/graph/findItem")
local removeItem = require("@root/graph/removeItem")
local testing = require("@root/testing")

local task = testing.task

test.case("removing the last item of a nested group also drops the group above it when it empties", function(assert)
	local doc = testing.createDoc({
		testing.group("outer", "Outer"),
		testing.group("inner", "Inner", "outer"),
		task("a", "A", "todo", "inner"),
		testing.group("spare", "Spare"),
	})
	removeItem(doc, "a")
	assert.eq(findItem(doc, "inner"), nil)
	assert.eq(findItem(doc, "outer"), nil)
	assert.eq(findItem(doc, "spare") ~= nil, true)
end)
