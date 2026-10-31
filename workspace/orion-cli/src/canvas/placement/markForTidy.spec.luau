local test = require("@std/test")

local markForTidy = require("@root/canvas/placement/markForTidy")
local testing = require("@root/testing")

test.case("markForTidy marks custom groups too and keeps a pending marker", function(assert)
	local custom = testing.group("c", "Custom")
	custom.data.arrange = "custom"
	local pending = testing.group("p", "Pending")
	pending.data.layout = "pending"
	local doc = testing.createDoc({ custom, pending, testing.task("a", "A", "todo") })
	markForTidy(doc, "c")
	markForTidy(doc, "p")
	assert.eq(custom.data.layout, "refit")
	assert.eq(pending.data.layout, "pending")
	assert.throwsWith('"a" is an item, not a group', function()
		markForTidy(doc, "a")
	end)
end)
