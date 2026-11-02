local test = require("@std/test")

local checkState = require("@root/canvas/cardTypes/checkState")
local findState = require("@root/canvas/cardTypes/findState")
local getStateMeaning = require("@root/canvas/cardTypes/getStateMeaning")
local testing = require("@root/testing")
local writeDoc = require("@root/storage/canvases/writeDoc")

local DESIGN = {
	name = "design",
	label = "Design",
	pack = "test",
	fields = {},
	face = { layout = "card", shows = {} },
	states = {
		{ name = "sketching", label = "Sketching", means = "active" },
		{ name = "approved", label = "Approved", means = "done" },
	},
	meaning = { isWork = true, canBlock = true, canBeDone = true, doneWhen = "state" },
}

test.case("getStateMeaning reads a recorded state through the card's type", function(assert)
	testing.withCardTypes({ DESIGN :: any }, function()
		assert.eq(getStateMeaning(testing.task("a", "A", "approved", nil, { type = "design" })), "done")
		assert.eq(getStateMeaning(testing.task("a", "A", "sketching", nil, { type = "design" })), "active")
		-- A shipped state the type doesn't declare means nothing to it.
		assert.eq(getStateMeaning(testing.task("a", "A", "done", nil, { type = "design" })), "todo")
	end)
end)

test.case("getStateMeaning reads shipped states as themselves, even on a type with none", function(assert)
	assert.eq(getStateMeaning(testing.task("a", "A", "deferred")), "deferred")
	assert.eq(getStateMeaning(testing.task("n", "", "done", nil, { type = "note" })), "done")
	assert.eq(getStateMeaning(testing.task("a", "A", "later")), "todo")
end)

test.case("findState names the state that records a meaning for the card's type", function(assert)
	testing.withCardTypes({ DESIGN :: any }, function()
		assert.eq(findState(testing.task("a", "A", "sketching", nil, { type = "design" }), "done"), "approved")
		assert.eq(findState(testing.task("a", "A", "sketching", nil, { type = "design" }), "deferred"), "deferred")
		assert.eq(findState(testing.task("a", "A", "todo"), "done"), "done")
	end)
end)

test.case("checkState takes only the states the card's type declares", function(assert)
	testing.withCardTypes({ DESIGN :: any }, function()
		checkState(testing.task("a", "A", "todo", nil, { type = "design" }), "approved")
		assert.throwsWith("status must be one of sketching, approved", function()
			checkState(testing.task("a", "A", "todo", nil, { type = "design" }), "done")
		end)
	end)

	assert.throwsWith("status must be one of todo, active, review, blocked, deferred, done", function()
		checkState(testing.task("a", "A", "todo"), "later")
	end)
	checkState(testing.task("n", "", "todo", nil, { type = "note" }), "done")
end)

test.case("derive and card done follow a type's states", function(assert)
	testing.withCardTypes({ DESIGN :: any }, function()
		local dir = testing.directory("type-states")
		writeDoc(
			dir,
			testing.createDoc({
				testing.task("design", "Design", "sketching", nil, { type = "design" }),
				testing.task("build", "Build", "todo"),
			}, { { "design", "build" } })
		)

		assert.strContains(testing.run(dir, { "node", "show", "build" }), "blocked")
		testing.run(dir, { "card", "done", "design" })
		assert.strContains(testing.run(dir, { "node", "show", "design" }), "recorded approved")
		assert.strContains(testing.run(dir, { "node", "show", "build" }), "status   ready")
	end)
end)
