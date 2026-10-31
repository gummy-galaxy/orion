local test = require("@std/test")

local countProgress = require("@root/canvas/items/countProgress")
local derive = require("@root/canvas/derive")
local testing = require("@root/testing")

test.case("countProgress reads a group's totals and counts nothing for an unknown group", function(assert)
	local doc = testing.createDoc({
		testing.group("g", "Group"),
		testing.task("a", "A", "done", "g"),
		testing.task("b", "B", "todo", "g"),
		testing.task("api", "API", "todo", "g", { itemKind = "component" }),
	})
	local derived = derive(doc)
	assert.eq(countProgress(derived, "g"), { total = 2, done = 1, ready = 1, components = 1 })
	assert.eq(countProgress(derived, "missing"), { total = 0, done = 0, ready = 0, components = 0 })
end)
