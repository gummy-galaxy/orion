local test = require("@std/test")

local checkLayout = require("@root/canvas/placement/checkLayout")
local testing = require("@root/testing")

local task = testing.task

local function placed(item: any, x: number, y: number): any
	item.position = { x = x, y = y }
	return item
end

test.case("a clean layout reports nothing", function(assert)
	local outer = testing.group("outer", "Outer")
	outer.width = 600
	outer.height = 300
	local doc = testing.createDoc({
		outer,
		placed(task("a", "A", "todo", "outer"), 32, 78),
		placed(task("b", "B", "todo", "outer"), 280, 78),
	})
	assert.eq(#checkLayout(doc), 0)
end)

test.case("overlapping siblings report their shared area, and touching edges don't count", function(assert)
	local doc = testing.createDoc({
		placed(task("x", "X", "todo"), 0, 0),
		placed(task("y", "Y", "todo"), 200, 0),
		placed(task("z", "Z", "todo"), 216, 100),
	})
	local issues = checkLayout(doc)
	assert.eq(#issues, 1)
	assert.eq(issues[1].kind, "overlap")
	assert.eq(issues[1].ids[1], "x")
	assert.eq(issues[1].ids[2], "y")
	local bounds = issues[1].bounds
	assert.eq(bounds and bounds.x, 200)
	assert.eq(bounds and bounds.y, 0)
	assert.eq(bounds and bounds.width, 16)
	assert.eq(bounds and bounds.height, 72)
end)

test.case("children are measured in canvas coordinates", function(assert)
	local outer = placed(testing.group("outer", "Outer"), 100, 50)
	outer.width = 300
	outer.height = 200
	local doc = testing.createDoc({
		outer,
		placed(task("a", "A", "todo", "outer"), 250, 0),
	})
	local issues = checkLayout(doc)
	assert.eq(#issues, 1)
	assert.eq(issues[1].kind, "outside-group")
	assert.eq(issues[1].ids[1], "a")
	assert.eq(issues[1].ids[2], "outer")
	local bounds = issues[1].bounds
	assert.eq(bounds and bounds.x, 350)
	assert.eq(bounds and bounds.y, 50)
	assert.eq(bounds and bounds.width, 216)
	assert.eq(bounds and bounds.height, 72)
end)

test.case("groups marked for layout are waiting for it, and links to missing items are dangling", function(assert)
	local waiting = placed(testing.group("waiting", "Waiting"), 10, 20)
	waiting.data.layout = "refit"
	local doc = testing.createDoc({ waiting, placed(task("a", "A", "todo"), 500, 0) }, { { "a", "gone" } })
	local issues = checkLayout(doc)
	assert.eq(#issues, 2)
	assert.eq(issues[1].kind, "waiting-for-layout")
	assert.eq(issues[1].ids[1], "waiting")
	local bounds = issues[1].bounds
	assert.eq(bounds and bounds.x, 10)
	assert.eq(bounds and bounds.width, 400)
	assert.eq(issues[2].kind, "dangling-link")
	assert.eq(issues[2].ids[1], "a")
	assert.eq(issues[2].ids[2], "gone")
	assert.eq(issues[2].bounds, nil)
end)

test.case("a group limits reports to itself and what is inside it", function(assert)
	local outer = placed(testing.group("outer", "Outer"), 0, 400)
	outer.width = 600
	outer.height = 300
	local waiting = placed(testing.group("waiting", "Waiting"), 800, 0)
	waiting.data.layout = "refit"
	local doc = testing.createDoc({
		placed(task("x", "X", "todo"), 0, 0),
		placed(task("y", "Y", "todo"), 100, 0),
		outer,
		placed(task("a", "A", "todo", "outer"), 32, 78),
		placed(task("b", "B", "todo", "outer"), 100, 78),
		waiting,
	}, { { "a", "gone" } })

	local whole = checkLayout(doc)
	assert.eq(#whole, 4)

	local scoped = checkLayout(doc, "outer")
	assert.eq(#scoped, 2)
	assert.eq(scoped[1].kind, "overlap")
	assert.eq(scoped[1].ids[1], "a")
	assert.eq(scoped[2].kind, "dangling-link")
	assert.throwsWith('"a" is an item, not a group', function()
		checkLayout(doc, "a")
	end)
end)
