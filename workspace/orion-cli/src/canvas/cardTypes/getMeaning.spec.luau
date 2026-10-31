local test = require("@std/test")

local getMeaning = require("@root/canvas/cardTypes/getMeaning")
local testing = require("@root/testing")

test.case("getMeaning reads the primary type's declaration", function(assert)
	local gate = getMeaning(testing.task("g", "Ship", "todo", nil, { type = "gate" })) :: any
	local note = getMeaning(testing.task("n", "", "todo", nil, { type = "note" })) :: any

	assert.eq(gate.doneWhen, "inputs")
	assert.eq(gate.isWork, true)
	assert.eq(note.isWork, false)
	assert.eq(note.canBlock, false)
end)

test.case("getMeaning reads a type nothing registers as a step", function(assert)
	local meaning = getMeaning(testing.task("a", "A", "todo", nil, { type = "timer" })) :: any

	assert.eq(meaning.isWork, true)
	assert.eq(meaning.doneWhen, "state")
end)

test.case("getMeaning gives groups none", function(assert)
	assert.eq(getMeaning(testing.group("g", "Group")), nil)
end)
