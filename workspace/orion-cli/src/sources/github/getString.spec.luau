local test = require("@std/test")

local getString = require("@root/sources/github/getString")

test.case("string values pass through", function(assert)
	assert.eq(getString("hello"), "hello")
	assert.eq(getString(42), nil)
end)
