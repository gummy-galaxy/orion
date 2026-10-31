local test = require("@std/test")

local snooze = require("@root/canvas/items/snooze")
local testing = require("@root/testing")

local task = testing.task

test.case("snooze sets and clears a work item's wake time, and refuses groups and notes", function(assert)
	local doc = testing.createDoc({
		testing.group("g", "G"),
		task("a", "A", "todo"),
		task("n", "Note", "todo", nil, { itemKind = "note" }),
	})
	snooze(doc, "a", "2026-10-12T17:00:00Z")
	assert.eq(doc.nodes[2].data.snoozedUntil, "2026-10-12T17:00:00Z")
	snooze(doc, "a", nil)
	assert.eq(doc.nodes[2].data.snoozedUntil, nil)
	assert.throws(function()
		snooze(doc, "g", "2026-10-12T17:00:00Z")
	end)
	assert.throws(function()
		snooze(doc, "n", "2026-10-12T17:00:00Z")
	end)
end)
