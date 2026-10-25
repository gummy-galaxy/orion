local test = require("@std/test")

local insertBetween = require("@root/graph/insertBetween")
local linkItems = require("@root/graph/linkItems")
local testing = require("@root/testing")

local task = testing.task

test.case("link sets, keeps, and clears a label, and insertBetween keeps it on the first half", function(assert)
	local doc = testing.createDoc({ task("a", "A", "todo"), task("b", "B", "todo"), task("n", "N", "todo") })
	local link = linkItems(doc, "a", "b", "blocks", "  HTTP  ")
	assert.eq(link.label, "HTTP")
	linkItems(doc, "a", "b", "related")
	assert.eq(link.label, "HTTP")
	assert.eq(link.kind, "related")

	insertBetween(doc, "n", "a", "b")
	assert.eq(doc.links[1].label, "HTTP")
	assert.eq(doc.links[2].label, nil)

	linkItems(doc, "a", "n", "related", "")
	assert.eq(doc.links[1].label, nil)
end)
