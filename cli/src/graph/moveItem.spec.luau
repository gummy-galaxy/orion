local test = require("@std/test")

local findItem = require("@root/graph/findItem")
local getItem = require("@root/graph/getItem")
local moveItem = require("@root/graph/moveItem")
local testing = require("@root/testing")
local ungroup = require("@root/graph/ungroup")

local task = testing.task

test.case("move marks the group it moves into, and ungroup marks the group that takes its items", function(assert)
	local doc = testing.createDoc({
		testing.group("outer", "Outer"),
		testing.group("inner", "Inner", "outer"),
		task("x", "X", "todo", "inner"),
		testing.group("other", "Other"),
		task("y", "Y", "todo"),
	})
	moveItem(doc, "y", "other")
	assert.eq(getItem(doc, "other").data.layout, "refit")
	ungroup(doc, "inner")
	assert.eq(getItem(doc, "x").parentId, "outer")
	assert.eq(getItem(doc, "outer").data.layout, "refit")
end)

test.case("tidying a group the CLI joins keeps a pending marker and skips custom groups", function(assert)
	local pending = testing.group("pending", "Pending")
	pending.data.layout = "pending"
	local custom = testing.group("custom", "Custom")
	custom.data.arrange = "custom"
	local doc = testing.createDoc({
		pending,
		custom,
		task("a", "A", "todo"),
		task("b", "B", "todo"),
		task("c", "C", "todo", "custom"),
	})
	moveItem(doc, "a", "pending")
	assert.eq(pending.data.layout, "pending")
	moveItem(doc, "b", "custom")
	assert.eq(custom.data.layout, nil)
end)

test.case("move drops groups it leaves empty and refuses cycles", function(assert)
	local doc = testing.createDoc({ testing.group("g", "G"), testing.group("h", "H"), task("a", "A", "todo", "g") })
	moveItem(doc, "a", "h")
	assert.eq(findItem(doc, "g"), nil)
	assert.throws(function()
		moveItem(doc, "h", "h")
	end)
end)

test.case("an empty group made on purpose survives moves elsewhere, and emptied groups still go", function(assert)
	local doc = testing.createDoc({
		testing.group("g", "G"),
		testing.group("h", "H"),
		testing.group("kept", "Kept"),
		task("a", "A", "todo", "g"),
		task("b", "B", "todo"),
	})
	moveItem(doc, "a", "h")
	assert.eq(findItem(doc, "g"), nil)
	assert.eq(findItem(doc, "kept") ~= nil, true)
end)
