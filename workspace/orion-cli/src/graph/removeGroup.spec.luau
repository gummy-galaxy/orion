local test = require("@std/test")

local findItem = require("@root/graph/findItem")
local removeGroup = require("@root/graph/removeGroup")
local testing = require("@root/testing")

test.case("removeGroup removes a group with everything inside, reconnecting around notes", function(assert)
	local doc = testing.createDoc({
		testing.group("g", "Group"),
		testing.group("inner", "Inner", "g"),
		testing.task("a", "A", "todo"),
		testing.task("n", "Note", "todo", "inner", { type = "note" }),
		testing.task("b", "B", "todo"),
	}, { { "a", "n" }, { "n", "b" } })
	removeGroup(doc, "g")
	assert.eq(#doc.nodes, 2)
	assert.eq(findItem(doc, "inner"), nil)
	assert.eq(#doc.links, 1)
	assert.eq({ doc.links[1].from, doc.links[1].to }, { "a", "b" })
end)

test.case("removeGroup drops a parent it leaves empty", function(assert)
	local doc = testing.createDoc({
		testing.group("outer", "Outer"),
		testing.group("inner", "Inner", "outer"),
		testing.task("a", "A", "todo", "inner"),
	})
	removeGroup(doc, "inner")
	assert.eq(#doc.nodes, 0)
end)
