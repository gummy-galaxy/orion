local test = require("@std/test")

local formatTimestamp = require("@root/common/time/formatTimestamp")

test.case("formats a time as UTC in ISO 8601", function(assert)
	assert.eq(formatTimestamp(0), "1970-01-01T00:00:00Z")
	assert.eq(formatTimestamp(1793462400), "2026-10-31T16:00:00Z")
end)

test.case("formats the current time when given none", function(assert)
	assert.eq(formatTimestamp():match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$") ~= nil, true)
end)
