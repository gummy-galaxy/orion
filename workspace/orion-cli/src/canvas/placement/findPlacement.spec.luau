local test = require("@std/test")

local findPlacement = require("@root/canvas/placement/findPlacement")
local geometry = require("@root/geometry")
local testing = require("@root/testing")

local gap = geometry.GAP.inner
local width = geometry.TASK_WIDTH
local height = geometry.TASK_HEIGHT
local pitch = { x = width + gap.x, y = height + gap.y }

local function at(id: string, x: number, y: number, parentId: string?)
	local item = testing.task(id, id, "todo", if parentId == nil then "g" else parentId)
	item.position = { x = x, y = y }
	return item
end

local function newCard(parentId: string?)
	return testing.task("new", "New", "todo", parentId)
end

test.case("findPlacement puts a card one pitch right of the card that blocks it, on its row", function(assert)
	local doc = testing.createDoc({ testing.group("g", "G"), at("a", 32, 78), at("b", 32 + pitch.x * 3, 78) }, {
		{ "a", "new" },
	})
	assert.eq(findPlacement(doc, newCard("g")), { x = 32 + pitch.x, y = 78 })
end)

test.case("findPlacement follows the predecessor that reaches furthest right", function(assert)
	local doc = testing.createDoc({ testing.group("g", "G"), at("a", 32, 78), at("b", 32 + pitch.x, 78 + pitch.y) }, {
		{ "a", "new" },
		{ "b", "new" },
	})
	assert.eq(findPlacement(doc, newCard("g")), { x = 32 + pitch.x * 2, y = 78 + pitch.y })
end)

test.case("findPlacement breaks a tie between predecessors by the higher one", function(assert)
	local doc = testing.createDoc({ testing.group("g", "G"), at("low", 32, 78 + pitch.y), at("high", 32, 78) }, {
		{ "low", "new" },
		{ "high", "new" },
	})
	assert.eq(findPlacement(doc, newCard("g")), { x = 32 + pitch.x, y = 78 })
end)

test.case("findPlacement steps down a row when the spot beside its predecessor is taken", function(assert)
	local doc = testing.createDoc({ testing.group("g", "G"), at("a", 32, 78), at("b", 32 + pitch.x, 78) }, {
		{ "a", "b" },
		{ "a", "new" },
	})
	assert.eq(findPlacement(doc, newCard("g")), { x = 32 + pitch.x, y = 78 + pitch.y })
end)

test.case("findPlacement puts a card one pitch left of the leftmost card it blocks", function(assert)
	local doc = testing.createDoc({
		testing.group("g", "G"),
		at("a", 32 + pitch.x * 2, 78),
		at("b", 32 + pitch.x * 3, 78 + pitch.y),
	}, { { "new", "a" }, { "new", "b" } })
	assert.eq(findPlacement(doc, newCard("g")), { x = 32 + pitch.x, y = 78 })
end)

test.case("findPlacement prefers a predecessor over a successor", function(assert)
	local doc = testing.createDoc({ testing.group("g", "G"), at("a", 32, 78), at("b", 32 + pitch.x * 4, 78) }, {
		{ "new", "b" },
		{ "a", "new" },
	})
	assert.eq(findPlacement(doc, newCard("g")), { x = 32 + pitch.x, y = 78 })
end)

test.case("findPlacement ignores related links and links that leave the group", function(assert)
	local outside = testing.task("outside", "Outside", "todo")
	outside.position = { x = 2000, y = 2000 }
	local doc = testing.createDoc({ testing.group("g", "G"), at("a", 32, 78), outside }, {
		{ "a", "new", "related" },
		{ "outside", "new" },
	})
	assert.eq(findPlacement(doc, newCard("g")), { x = 32, y = 78 + pitch.y })
end)

test.case("findPlacement falls back when the spot left of a successor crosses the group's edge", function(assert)
	local doc = testing.createDoc({ testing.group("g", "G"), at("a", 32, 78) }, { { "new", "a" } })
	assert.eq(findPlacement(doc, newCard("g")), { x = 32, y = 78 + pitch.y })
end)

test.case("findPlacement starts an empty group below its title row", function(assert)
	local doc = testing.createDoc({ testing.group("g", "G") })
	assert.eq(findPlacement(doc, newCard("g")), { x = geometry.GROUP_PADDING, y = geometry.GROUP_HEADER_HEIGHT })
end)

test.case("findPlacement continues an unlinked card along the last row while it fits", function(assert)
	local group = testing.group("g", "G")
	group.width = 32 + pitch.x * 3 + 32
	local doc = testing.createDoc({ group, at("a", 32, 78), at("b", 32 + pitch.x * 2, 78), at("c", 32, 78 + pitch.y) })
	assert.eq(findPlacement(doc, newCard("g")), { x = 32 + pitch.x, y = 78 + pitch.y })
end)

test.case("findPlacement wraps an unlinked card to a new row rather than widening the group", function(assert)
	local group = testing.group("g", "G")
	group.width = 32 + pitch.x * 2 + 32
	local doc = testing.createDoc({ group, at("a", 32, 78), at("b", 32 + pitch.x, 78) })
	assert.eq(findPlacement(doc, newCard("g")), { x = 32, y = 78 + pitch.y })
end)

test.case("findPlacement uses room a custom group keeps past its cards", function(assert)
	local group = testing.group("g", "G")
	group.width = 32 + pitch.x * 4 + 32
	local doc = testing.createDoc({ group, at("a", 32, 78) })
	assert.eq(findPlacement(doc, newCard("g")), { x = 32 + pitch.x, y = 78 })
end)

test.case("findPlacement leaves out unplaced items, so items added together place in turn", function(assert)
	local doc = testing.createDoc({ testing.group("g", "G"), at("a", 32, 78), at("b", 900, 900) }, {
		{ "b", "new" },
	})
	assert.eq(findPlacement(doc, newCard("g"), { b = true }), { x = 32, y = 78 + pitch.y })
end)

test.case("findPlacement keeps a top-level card without links right of everything", function(assert)
	local top = testing.task("top", "Top", "todo")
	top.position = { x = 10, y = 20 }
	local doc = testing.createDoc({ top })
	assert.eq(findPlacement(doc, newCard(nil)), { x = 10 + width + geometry.GAP.top.component, y = 20 })
end)

test.case("findPlacement places a top-level card beside its predecessor with the top-level gap", function(assert)
	local top = testing.task("top", "Top", "todo")
	top.position = { x = 10, y = 20 }
	local doc = testing.createDoc({ top }, { { "top", "new" } })
	assert.eq(findPlacement(doc, newCard(nil)), { x = 10 + width + geometry.GAP.top.x, y = 20 })
end)
