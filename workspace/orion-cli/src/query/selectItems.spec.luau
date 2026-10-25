local test = require("@std/test")

local selectItems = require("@root/query/selectItems")
local testing = require("@root/testing")

test.case("selection keeps document order and excludes done cards unless asked", function(assert)
	local doc = testing.createDoc({
		testing.task("first", "First", "done", nil, { repo = "orion" }),
		testing.task("second", "Second", "todo", nil, { repo = "orion" }),
	})
	local expression = [[repo = "orion"]]
	local open = selectItems(doc, expression, false)
	assert.eq(#open, 1)
	assert.eq(open[1].id, "second")
	local all = selectItems(doc, expression, true)
	assert.eq(#all, 2)
	assert.eq(all[1].id, "first")
	assert.eq(all[2].id, "second")
end)
