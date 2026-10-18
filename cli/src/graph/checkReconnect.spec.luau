local test = require("@std/test")

local checkReconnect = require("@root/graph/checkReconnect")
local testing = require("@root/testing")

test.case("checkReconnect allows one link in and one out, and refuses more", function(assert)
	local doc = testing.createDoc({
		testing.task("a", "A", "todo"),
		testing.task("b", "B", "todo"),
		testing.task("c", "C", "todo"),
		testing.task("d", "D", "todo"),
	}, { { "a", "b" }, { "b", "c" }, { "d", "c" } })
	checkReconnect(doc, "b")
	checkReconnect(doc, "a")
	assert.throwsWith('"c" needs at most one incoming and one outgoing link to reconnect', function()
		checkReconnect(doc, "c")
	end)
end)
