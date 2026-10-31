local test = require("@std/test")

local findItem = require("@root/canvas/items/findItem")
local pruneEmptied = require("@root/canvas/groups/pruneEmptied")
local testing = require("@root/testing")

test.case("pruneEmptied removes an empty group and each empty group above it", function(assert)
	local doc = testing.createDoc({
		testing.group("top", "Top"),
		testing.group("outer", "Outer", "top"),
		testing.group("inner", "Inner", "outer"),
		testing.task("a", "A", "todo", "top"),
	})
	pruneEmptied(doc, "inner")
	assert.eq(findItem(doc, "inner"), nil)
	assert.eq(findItem(doc, "outer"), nil)
	assert.eq(findItem(doc, "top") ~= nil, true)
end)

test.case("pruneEmptied keeps a group with something inside and ignores cards and nil", function(assert)
	local doc = testing.createDoc({ testing.group("g", "Group"), testing.task("a", "A", "todo", "g") })
	pruneEmptied(doc, "g")
	pruneEmptied(doc, "a")
	pruneEmptied(doc, nil)
	assert.eq(#doc.nodes, 2)
end)
