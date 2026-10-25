local test = require("@std/test")

local joinWords = require("@root/cli/joinWords")

test.case("joinWords joins words with spaces", function(assert)
	assert.eq(joinWords({ "Ship", "the", "release" }, "<label>"), "Ship the release")
end)

test.case("joinWords names what's missing when there are no words", function(assert)
	assert.throwsWith("missing <label>", function()
		joinWords({}, "<label>")
	end)
end)
