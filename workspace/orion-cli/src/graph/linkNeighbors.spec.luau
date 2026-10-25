local test = require("@std/test")

local linkNeighbors = require("@root/graph/linkNeighbors")
local testing = require("@root/testing")

local task = testing.task

test.case("linkNeighbors splits an existing link and keeps its kind", function(assert)
	local doc = testing.createDoc(
		{ task("a", "A", "todo"), task("n", "N", "todo"), task("b", "B", "todo") },
		{ { "a", "b", "related" } }
	)
	linkNeighbors(doc, "n", "a", "b")
	assert.eq(#doc.links, 2)
	assert.eq(doc.links[1].kind, "related")
	assert.eq(doc.links[2].kind, "related")
end)

test.case("linkNeighbors adds blocking links on each side it's given", function(assert)
	local doc = testing.createDoc({ task("a", "A", "todo"), task("n", "N", "todo"), task("b", "B", "todo") })
	linkNeighbors(doc, "n", "a", "b")
	assert.eq(#doc.links, 2)
	assert.eq(doc.links[1].from, "a")
	assert.eq(doc.links[1].to, "n")
	assert.eq(doc.links[2].from, "n")
	assert.eq(doc.links[2].to, "b")
	assert.eq(doc.links[2].kind, "blocks")

	linkNeighbors(doc, "n", nil, nil)
	assert.eq(#doc.links, 2)
end)
