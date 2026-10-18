local test = require("@std/test")

local getUniqueId = require("@root/graph/getUniqueId")
local testing = require("@root/testing")

test.case("getUniqueId keeps a free id and suffixes a taken one", function(assert)
	local doc = testing.createDoc({ testing.task("ship", "Ship", "todo"), testing.task("ship-2", "Ship", "todo") })
	assert.eq(getUniqueId(doc, "release"), "release")
	assert.eq(getUniqueId(doc, "ship"), "ship-3")
end)
