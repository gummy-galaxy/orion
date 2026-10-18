local test = require("@std/test")

local getRecordedStatuses = require("@root/graph/getRecordedStatuses")
local testing = require("@root/testing")

test.case("getRecordedStatuses reads each card's stored status, defaulting to todo", function(assert)
	local doc = testing.createDoc({
		testing.group("g", "Group"),
		testing.task("a", "A", "done"),
		testing.task("b", "B", "todo", nil, { status = false }),
	})
	assert.eq(getRecordedStatuses(doc), { a = "done", b = "todo" })
end)
