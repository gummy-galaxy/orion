local test = require("@std/test")

local getBinaryFingerprint = require("@root/cli/mcp/server/getBinaryFingerprint")

test.case("getBinaryFingerprint describes the running executable and repeats until it changes", function(assert)
	local first = getBinaryFingerprint()

	assert.neq(first, nil)
	assert.eq(getBinaryFingerprint(), first)
end)
