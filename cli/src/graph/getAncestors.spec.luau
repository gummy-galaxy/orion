local test = require("@std/test")

local getAncestors = require("@root/graph/getAncestors")
local testing = require("@root/testing")

test.case("getAncestors lists the groups above an item, nearest first", function(assert)
	local doc = testing.createDoc({
		testing.group("outer", "Outer"),
		testing.group("inner", "Inner", "outer"),
		testing.task("a", "A", "todo", "inner"),
	})
	assert.eq(getAncestors(doc, "a"), { "inner", "outer" })
	assert.eq(getAncestors(doc, "outer"), {})
	assert.eq(getAncestors(doc, "missing"), {})
end)
