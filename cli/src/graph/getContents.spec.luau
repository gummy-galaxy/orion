local test = require("@std/test")

local getContents = require("@root/graph/getContents")
local testing = require("@root/testing")

test.case("getContents lists everything inside a group, parents before their children", function(assert)
	local doc = testing.createDoc({
		testing.task("deep", "Deep", "todo", "inner"),
		testing.group("outer", "Outer"),
		testing.group("inner", "Inner", "outer"),
		testing.task("a", "A", "todo", "outer"),
		testing.task("b", "B", "todo"),
	})
	local ids = {}

	for _, item in getContents(doc, "outer") do
		table.insert(ids, item.id)
	end

	assert.eq(ids, { "inner", "a", "deep" })
	assert.eq(getContents(doc, "b"), {})
end)
