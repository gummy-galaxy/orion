local test = require("@std/test")

local markForRefit = require("@root/canvas/placement/markForRefit")
local testing = require("@root/testing")

test.case("markForRefit marks a group, keeps a pending marker, and skips custom groups", function(assert)
	local group = testing.group("g", "Group")
	markForRefit(group)
	assert.eq(group.data.layout, "refit")

	local pending = testing.group("p", "Pending")
	pending.data.layout = "pending"
	markForRefit(pending)
	assert.eq(pending.data.layout, "pending")

	local custom = testing.group("c", "Custom")
	custom.data.arrange = "custom"
	markForRefit(custom)
	assert.eq(custom.data.layout, nil)
end)
