local test = require("@std/test")

local getErrorText = require("@root/common/errors/getErrorText")

test.case("strips the position Luau adds to an error", function(assert)
	local _, failure = pcall(error, 'no item or group with id "missing"')
	assert.eq(getErrorText(failure), 'no item or group with id "missing"')
end)

test.case("gives a table error's message rather than its address", function(assert)
	local rejection = { rejected = true, index = 1, op = "move", message = 'no item or group with id "missing"' }
	assert.eq(getErrorText(rejection), 'no item or group with id "missing"')
end)
