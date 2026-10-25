local test = require("@std/test")

local insertBetween = require("@root/graph/insertBetween")
local testing = require("@root/testing")

test.case("insertBetween routes a link through an item and keeps its kind", function(assert)
	local doc = testing.createDoc(
		{ testing.task("a", "A", "todo"), testing.task("n", "N", "todo"), testing.task("b", "B", "todo") },
		{ { "a", "b", "related" } }
	)
	insertBetween(doc, "n", "a", "b")
	assert.eq(#doc.links, 2)
	assert.eq({ doc.links[1].from, doc.links[1].to, doc.links[1].kind }, { "a", "n", "related" })
	assert.eq({ doc.links[2].from, doc.links[2].to, doc.links[2].kind }, { "n", "b", "related" })
end)

test.case("insertBetween refuses a missing link, a group, and the link's own ends", function(assert)
	local doc = testing.createDoc({
		testing.group("g", "Group"),
		testing.task("a", "A", "todo"),
		testing.task("n", "N", "todo"),
		testing.task("b", "B", "todo"),
	}, { { "a", "b" } })
	assert.throwsWith('no link from "b" to "a"', function()
		insertBetween(doc, "n", "b", "a")
	end)
	assert.throwsWith('"g" is a group; link the items inside it', function()
		insertBetween(doc, "g", "a", "b")
	end)
	assert.throwsWith("an item can't link to itself", function()
		insertBetween(doc, "a", "a", "b")
	end)
end)
