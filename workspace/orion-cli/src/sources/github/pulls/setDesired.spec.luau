local test = require("@std/test")

local getStateMeaning = require("@root/canvas/cardTypes/getStateMeaning")
local setDesired = require("@root/sources/github/pulls/setDesired")
local testing = require("@root/testing")

local pull = testing.pull

test.case("setDesired defers a card whose pull request closed and marks the deferral as its own", function(assert)
	local item = testing.task("a", "Work", "active")
	setDesired(item, pull("CLOSED"), "vocksel")
	assert.eq(item.data.status, "deferred")
	assert.eq(item.data.deferredByClosedPull, true)
end)

test.case("setDesired follows a reopened pull request and drops its own deferral", function(assert)
	local item = testing.task("a", "Work", "deferred", nil, { deferredByClosedPull = true })
	setDesired(item, pull("OPEN"), "vocksel")
	assert.eq(item.data.status, "review")
	assert.eq(item.data.who, "you")
	assert.eq(item.data.deferredByClosedPull, nil)
end)

test.case("setDesired keeps its own deferral while the pull request stays closed", function(assert)
	local item = testing.task("a", "Work", "deferred", nil, { deferredByClosedPull = true })
	setDesired(item, pull("CLOSED"), "vocksel")
	assert.eq(item.data.status, "deferred")
	assert.eq(item.data.deferredByClosedPull, true)
end)

test.case("setDesired leaves a deferral someone set alone when the pull request closes or reopens", function(assert)
	local item = testing.task("a", "Work", "deferred")
	setDesired(item, pull("CLOSED"), "vocksel")
	assert.eq(item.data.status, "deferred")
	assert.eq(item.data.deferredByClosedPull, nil)
	setDesired(item, pull("OPEN"), "vocksel")
	assert.eq(item.data.status, "deferred")
	assert.eq(item.data.deferredByClosedPull, nil)
end)

test.case("setDesired keeps a hold on an open pull request", function(assert)
	local item = testing.task("a", "Work", "blocked", nil, { who = "ci" })
	setDesired(item, pull("OPEN"), "vocksel")
	assert.eq(item.data.status, "blocked")
	assert.eq(item.data.who, "ci")
	assert.eq(item.data.deferredByClosedPull, nil)
end)

test.case("setDesired marks a merged pull request done and drops any deferral marker", function(assert)
	local item = testing.task("a", "Work", "deferred", nil, { deferredByClosedPull = true })
	setDesired(item, pull("MERGED"), "vocksel")
	assert.eq(item.data.status, "done")
	assert.eq(item.data.who, nil)
	assert.eq(item.data.deferredByClosedPull, nil)
end)

local DESIGN = {
	name = "design",
	label = "Design",
	pack = "test",
	fields = {},
	face = { layout = "card", shows = {} },
	states = {
		{ name = "sketching", label = "Sketching", means = "active" },
		{ name = "refining", label = "Refining", means = "active" },
		{ name = "approved", label = "Approved", means = "done" },
	},
	meaning = { isWork = true, canBlock = true, canBeDone = true, doneWhen = "state" },
}

local function design(status: string)
	return testing.task("a", "Work", status, nil, { type = "design" })
end

test.case("setDesired records the state a card's type declares for a merged pull request", function(assert)
	testing.withCardTypes({ DESIGN :: any }, function()
		local item = design("sketching")
		setDesired(item, pull("MERGED"), "vocksel")
		assert.eq(item.data.status, "approved")
		assert.eq(getStateMeaning(item), "done")
	end)
end)

test.case("setDesired keeps a card's state when its type has none for the meaning", function(assert)
	testing.withCardTypes({ DESIGN :: any }, function()
		local item = design("sketching")
		setDesired(item, pull("CLOSED"), "vocksel")
		assert.eq(item.data.status, "sketching")
		assert.eq(item.data.deferredByClosedPull, nil)
	end)
end)

test.case("setDesired keeps a state that already has the meaning the pull request decides", function(assert)
	testing.withCardTypes({ DESIGN :: any }, function()
		local draft = pull("OPEN")
		draft.draft = true
		local item = design("refining")
		setDesired(item, draft, "vocksel")
		assert.eq(item.data.status, "refining")
		assert.eq(item.data.who, "you")
	end)
end)
