local test = require("@std/test")

local syncPlacements = require("@root/canvas/placement/syncPlacements")
local testing = require("@root/testing")
local types = require("@root/types")

test.case("syncPlacements places each new node where it sits and remembers the id", function(assert)
	local doc = testing.createDoc({ testing.group("g", "Group"), testing.task("a", "A", "todo", "g") })
	doc.nodes[2].position = { x = 10, y = 20 }
	syncPlacements(doc)

	assert.eq(#doc.placements, 2)
	local placement = doc.placements[2]
	assert.eq(testing.isRandomId(placement.id), true)
	assert.eq(placement.node, "a")
	assert.eq(placement.parentId, "g")
	assert.eq(placement.position, { x = 10, y = 20 })
	assert.eq(doc.nodes[2].placement, placement.id)

	-- The placement keeps its own copy of the position.
	doc.nodes[2].position.x = 99
	assert.eq(placement.position.x, 10)
end)

test.case("syncPlacements moves a node's own placement and keeps its others as they are", function(assert)
	local doc = testing.createDoc({ testing.task("a", "A", "todo") })
	doc.nodes[1].placement = "own"
	doc.placements = {
		{ id = "other", node = "a", parentId = "g", position = { x = 1, y = 1 } },
		{ id = "own", node = "a", position = { x = 0, y = 0 } },
	}
	doc.nodes[1].position = { x = 5, y = 6 }
	syncPlacements(doc)

	assert.eq(#doc.placements, 2)
	assert.eq(doc.placements[1].id, "own")
	assert.eq(doc.placements[1].position, { x = 5, y = 6 })
	assert.eq(doc.placements[2].id, "other")
	assert.eq(doc.placements[2].parentId, "g")
	assert.eq(doc.placements[2].position, { x = 1, y = 1 })
end)

test.case("syncPlacements drops the placements of a removed node and restores them when it's put back", function(assert)
	local doc = testing.createDoc({ testing.task("a", "A", "todo"), testing.task("b", "B", "todo") })
	syncPlacements(doc)
	local before = table.clone(doc.placements)
	local removed = table.remove(doc.nodes, 1) :: types.Item
	syncPlacements(doc)

	assert.eq(#doc.placements, 1)
	assert.eq(doc.placements[1].node, "b")

	table.insert(doc.nodes, 1, removed)
	syncPlacements(doc)
	assert.eq(#doc.placements, 2)
	assert.eq(doc.placements[1].id, before[1].id)
	assert.eq(doc.placements[2].id, before[2].id)
end)

test.case("syncPlacements gives a copied node its own placement id", function(assert)
	local doc = testing.createDoc({ testing.task("a", "A", "todo") })
	syncPlacements(doc)
	local copy = table.clone(doc.nodes[1])
	copy.id = "copy"
	table.insert(doc.nodes, 1, copy)
	syncPlacements(doc)

	assert.eq(#doc.placements, 2)
	assert.neq(doc.placements[1].id, doc.placements[2].id)
	assert.eq(doc.placements[2].id, doc.nodes[2].placement)
end)

test.case("syncPlacements leaves an unplaced node off the canvas until a change moves it", function(assert)
	local doc = testing.createDoc({ testing.task("a", "A", "todo") })
	doc.nodes[1].unplaced = true
	syncPlacements(doc)

	assert.eq(#doc.placements, 0)
	assert.eq(doc.nodes[1].unplaced, true)

	doc.nodes[1].position = { x = 40, y = 0 }
	syncPlacements(doc)
	assert.eq(#doc.placements, 1)
	assert.eq(doc.placements[1].position, { x = 40, y = 0 })
	assert.eq(doc.nodes[1].unplaced, nil)
end)

return {}
