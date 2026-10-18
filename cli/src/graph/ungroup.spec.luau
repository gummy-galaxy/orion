local test = require("@std/test")

local testing = require("@root/testing")
local ungroup = require("@root/graph/ungroup")

test.case("ungroup hands a group's items to its parent and keeps them in place", function(assert)
	local outer = testing.group("outer", "Outer")
	local inner = testing.group("inner", "Inner", "outer")
	inner.position = { x = 40, y = 100 }
	local item = testing.task("a", "A", "todo", "inner")
	item.position = { x = 32, y = 78 }
	local doc = testing.createDoc({ outer, inner, item })
	ungroup(doc, "inner")
	assert.eq(item.parentId, "outer")
	assert.eq(item.position, { x = 72, y = 178 })
	assert.eq(#doc.nodes, 2)
	assert.eq(outer.data.layout, "refit")
end)
