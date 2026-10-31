local test = require("@std/test")

local isListed = require("@root/sources/github/pulls/isListed")

test.case("repository filters ignore case", function(assert)
	assert.eq(isListed({ "Orion" }, "orion"), true)
	assert.eq(isListed({ "Orion" }, "hop"), false)
	assert.eq(isListed(nil, "orion"), false)
end)
