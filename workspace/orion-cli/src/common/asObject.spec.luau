local test = require("@std/test")

local asObject = require("@root/common/asObject")

test.case("a table reads as an object", function(assert)
	local object = asObject({ code = "missing-item" })
	assert.eq(object and object.code, "missing-item")
end)

test.case("anything else is nil", function(assert)
	assert.eq(asObject("bad plan"), nil)
	assert.eq(asObject(nil), nil)
end)
