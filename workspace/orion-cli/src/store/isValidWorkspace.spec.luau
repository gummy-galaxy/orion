local test = require("@std/test")

local isValidWorkspace = require("@root/store/isValidWorkspace")

test.case("workspace names are lowercase slugs", function(assert)
	assert.eq(isValidWorkspace("default"), true)
	assert.eq(isValidWorkspace("focus-areas-2"), true)
	assert.eq(isValidWorkspace(""), false)
	assert.eq(isValidWorkspace("Focus"), false)
	assert.eq(isValidWorkspace("focus areas"), false)
	assert.eq(isValidWorkspace("../up"), false)
end)
