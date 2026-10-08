local test = require("@std/test")

local getKey = require("@root/github/getKey")
local getRefFor = require("@root/github/getRefFor")
local testing = require("@root/testing")

test.case("refFor reads bare and owner-qualified repositories", function(assert)
	local bare = getRefFor(testing.task("a", "A", "todo", nil, { repo = "flipbook", pr = 5 }), "flipbook-labs")
	assert.eq(bare and getKey(bare), "flipbook-labs/flipbook#5")
	local qualified =
		getRefFor(testing.task("b", "B", "todo", nil, { repo = "vocksel/orion", pr = 2 }), "flipbook-labs")
	assert.eq(qualified and getKey(qualified), "vocksel/orion#2")
	assert.eq(getRefFor(testing.task("c", "C", "todo"), "flipbook-labs"), nil)
end)
