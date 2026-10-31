local test = require("@std/test")

local makeGroup = require("@root/canvas/groups/makeGroup")
local testing = require("@root/testing")
local ungroup = require("@root/canvas/groups/ungroup")

local task = testing.task

test.case("makeGroup and ungroup keep items in place", function(assert)
	local firstTask = task("a", "A", "todo")
	firstTask.position = { x = 100, y = 50 }
	local doc = testing.createDoc({ firstTask, task("b", "B", "todo") })
	local group = makeGroup(doc, "Pair", { "a", "b" })
	assert.eq(firstTask.parentId, group.id)
	assert.eq(group.position.x + firstTask.position.x, 100)
	ungroup(doc, group.id)
	assert.eq(firstTask.parentId, nil)
	assert.eq(firstTask.position.x, 100)
	assert.eq(firstTask.position.y, 50)
end)

test.case("makeGroup marks the new group for the app to tidy", function(assert)
	local doc = testing.createDoc({ task("a", "A", "todo"), task("b", "B", "todo") })
	local group = makeGroup(doc, "Pair", { "a", "b" })
	assert.eq(group.data.layout, "refit")
end)
