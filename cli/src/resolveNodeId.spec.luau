local test = require("@std/test")

local resolveNodeId = require("@root/resolveNodeId")
local testing = require("@root/testing")

test.case("an id that exists is used as it is, even when a group has it as a label", function(assert)
	local doc = testing.createDoc({ testing.group("weekly", "Other"), testing.group("ws", "weekly") })
	assert.eq(resolveNodeId(doc, "weekly"), "weekly")
end)

test.case("a label names the one group that has it, ignoring case", function(assert)
	local doc = testing.createDoc({ testing.group("ws", "Release"), testing.group("q4", "Foundation components") })
	assert.eq(resolveNodeId(doc, "foundation COMPONENTS"), "q4")
end)

test.case("labels only match groups, and an unknown value comes back unchanged", function(assert)
	local doc = testing.createDoc({ testing.task("a", "Release", "todo"), testing.group("ws", "Release") })
	assert.eq(resolveNodeId(doc, "Release"), "ws")
	assert.eq(resolveNodeId(doc, "missing"), "missing")
end)

test.case("several groups with one label fail and list their ids", function(assert)
	local doc = testing.createDoc({ testing.group("w1", "Week"), testing.group("w2", "week") })
	assert.throwsWith('"Week" is the label of 2 groups; use one of their ids: w1 (Week), w2 (week)', function()
		resolveNodeId(doc, "Week")
	end)
end)
