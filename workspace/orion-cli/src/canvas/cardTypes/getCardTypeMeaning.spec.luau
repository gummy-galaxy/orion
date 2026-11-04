local test = require("@std/test")

local getCardTypeMeaning = require("@root/canvas/cardTypes/getCardTypeMeaning")
local testing = require("@root/testing")

test.case("getCardTypeMeaning reads the primary type's declaration", function(assert)
	local gate = getCardTypeMeaning(testing.task("g", "Ship", "todo", nil, { itemKind = "gate" })) :: any
	local note = getCardTypeMeaning(testing.task("n", "", "todo", nil, { itemKind = "note" })) :: any

	assert.eq(gate.doneWhen, "inputs")
	assert.eq(gate.isWork, true)
	assert.eq(note.isWork, false)
	assert.eq(note.canBlock, false)
end)

test.case("getCardTypeMeaning reads a type nothing registers as a step", function(assert)
	local meaning = getCardTypeMeaning(testing.task("a", "A", "todo", nil, { itemKind = "timer" })) :: any

	assert.eq(meaning.isWork, true)
	assert.eq(meaning.doneWhen, "state")
end)

test.case("getCardTypeMeaning gives groups none", function(assert)
	assert.eq(getCardTypeMeaning(testing.group("g", "Group")), nil)
end)
