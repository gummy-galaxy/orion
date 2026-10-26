local test = require("@std/test")

local getErrorCode = require("@root/getErrorCode")
local getErrorText = require("@root/getErrorText")
local raiseFailure = require("@root/raiseFailure")

test.case("a raised failure carries its code and reads as its message", function(assert)
	local _, failure = pcall(raiseFailure, "missing-item", 'no item or group with id "missing"')
	assert.eq(getErrorCode(failure), "missing-item")
	assert.eq(getErrorText(failure), 'no item or group with id "missing"')
	assert.eq(tostring(failure), 'no item or group with id "missing"')
end)

test.case("a plain error has no code", function(assert)
	local _, failure = pcall(error, "bad plan")
	assert.eq(getErrorCode(failure), nil)
end)
