local json = require("@std/json")
local test = require("@std/test")

local testing = require("@root/testing")

test.case("a write that printed only text prints its revision under --json", function(assert)
	local _, run = testing.createHarness("write-result-revision")
	local value = json.asObject(json.deserialize(run({ "link", "remove", "ci", "pub", "--json" })) :: json.Value)
	assert.eq(value and value.revision, 1)
	assert.eq(value and value.from, "ci")
	assert.eq(value and value.to, "pub")
end)

test.case("without --json the result stays a line of text", function(assert)
	local _, run = testing.createHarness("write-result-text")
	assert.eq(run({ "link", "remove", "ci", "pub" }), "Removed the link from ci to pub")
end)
