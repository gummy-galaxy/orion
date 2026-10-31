local test = require("@std/test")

local estimateTaskHeight = require("@root/canvas/placement/estimateTaskHeight")
local geometry = require("@root/geometry")
local testing = require("@root/testing")

local function note(label: string)
	return testing.task("n", label, "todo", nil, { type = "note" })
end

test.case("estimateTaskHeight keeps work cards at the card height", function(assert)
	local card = testing.task("a", string.rep("A long label ", 40), "todo")
	assert.eq(estimateTaskHeight(card), geometry.TASK_HEIGHT)
end)

test.case("estimateTaskHeight grows a note a line at a time and never below a card", function(assert)
	assert.eq(estimateTaskHeight(note("Short")), geometry.TASK_HEIGHT)
	-- Six lines of 15.6 under 36 of chrome, plus slack, rounded up to a
	-- multiple of 4.
	assert.eq(estimateTaskHeight(note("a\nb\nc\nd\ne\nf")), 136)
end)

test.case("estimateTaskHeight wraps long text between words and stops at the most a card grows", function(assert)
	-- About 25 characters fit on a note's line, so five four-letter words do
	-- and twelve take three lines.
	assert.eq(estimateTaskHeight(note(string.rep("word ", 12))), 88)
	assert.eq(estimateTaskHeight(note(string.rep("word ", 200))), geometry.TASK_MAX_HEIGHT)
	-- A word too long for a line breaks anywhere: 400 characters take 16 lines.
	assert.eq(estimateTaskHeight(note(string.rep("x", 400))), 292)
end)

test.case("estimateTaskHeight makes room for a component's description and shape", function(assert)
	local component = testing.task("c", "Server", "todo", nil, { type = "component" })
	assert.eq(estimateTaskHeight(component), geometry.TASK_HEIGHT)

	component.data.note = string.rep("Answers requests from the app. ", 6)
	local described = estimateTaskHeight(component)
	assert.eq(described > geometry.TASK_HEIGHT, true)

	component.data.shape = "store"
	assert.eq(estimateTaskHeight(component) > described, true)
end)
