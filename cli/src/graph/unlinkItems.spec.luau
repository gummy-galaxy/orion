local test = require("@std/test")

local testing = require("@root/testing")
local unlinkItems = require("@root/graph/unlinkItems")

test.case("unlinkItems removes the link between two items and refuses a missing one", function(assert)
	local doc = testing.createDoc(
		{ testing.task("a", "A", "todo"), testing.task("b", "B", "todo") },
		{ { "a", "b" }, { "b", "a", "related" } }
	)
	unlinkItems(doc, "a", "b")
	assert.eq(#doc.links, 1)
	assert.eq(doc.links[1].from, "b")
	assert.throwsWith('no link from "a" to "b"', function()
		unlinkItems(doc, "a", "b")
	end)
end)
