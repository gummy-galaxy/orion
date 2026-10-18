local test = require("@std/test")

local getRecordedStatuses = require("@root/graph/getRecordedStatuses")
local markCelebrations = require("@root/graph/markCelebrations")
local testing = require("@root/testing")

local task = testing.task

test.case("markCelebrations flags a card that turns done and clears the flag when it reopens", function(assert)
	local doc = testing.createDoc({ task("a", "A", "active"), task("b", "B", "done") })
	local previous = getRecordedStatuses(doc)
	doc.nodes[1].data.status = "done"
	markCelebrations(doc, previous)
	assert.eq(doc.nodes[1].data.celebrate, true)
	assert.eq(doc.nodes[2].data.celebrate, nil)

	previous = getRecordedStatuses(doc)
	doc.nodes[1].data.status = "todo"
	markCelebrations(doc, previous)
	assert.eq(doc.nodes[1].data.celebrate, nil)
end)

test.case("markCelebrations keeps a flag until the card is reopened, and skips new cards and notes", function(assert)
	local doc = testing.createDoc({
		task("a", "A", "done", nil, { celebrate = true }),
		task("created", "Created done", "done"),
		task("n", "Note", "todo", nil, { itemKind = "note" }),
	})
	local previous = getRecordedStatuses(doc)
	doc.nodes[1].data.label = "Renamed"
	doc.nodes[3].data.status = "done"
	markCelebrations(doc, previous)
	assert.eq(doc.nodes[1].data.celebrate, true)
	assert.eq(doc.nodes[2].data.celebrate, nil)
	assert.eq(doc.nodes[3].data.celebrate, nil)
end)
