local test = require("@std/test")

local encodeUrlComponent = require("@root/common/encodeUrlComponent")

test.case("query values keep only unreserved characters", function(assert)
	assert.eq(encodeUrlComponent("Fix the test"), "Fix%20the%20test")
	assert.eq(encodeUrlComponent("/Users/me/repo"), "%2FUsers%2Fme%2Frepo")
	assert.eq(encodeUrlComponent("a&b=c?d#e\n"), "a%26b%3Dc%3Fd%23e%0A")
	assert.eq(encodeUrlComponent("it's (ok)! ~_.-*"), "it's%20(ok)!%20~_.-*")
	assert.eq(encodeUrlComponent("é"), "%C3%A9")
end)
