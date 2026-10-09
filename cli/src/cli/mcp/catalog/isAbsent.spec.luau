local json = require("@std/json")
local test = require("@std/test")

local isAbsent = require("@root/cli/mcp/catalog/isAbsent")

test.case("missing and null arguments are absent", function(assert)
	assert.eq(isAbsent(nil), true)
	assert.eq(isAbsent(json.null), true)
	assert.eq(isAbsent(""), false)
	assert.eq(isAbsent(false), false)
end)
