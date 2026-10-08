local test = require("@std/test")

local getAbsolutePath = require("@root/platform/getAbsolutePath")

test.case("only absolute paths pass through", function(assert)
	assert.eq(getAbsolutePath("/data"), "/data")
	assert.eq(getAbsolutePath("relative"), nil)
	assert.eq(getAbsolutePath(""), nil)
	assert.eq(getAbsolutePath(nil), nil)
end)
