local test = require("@std/test")

local normalizeUntil = require("@root/checks/normalizeUntil")

test.case("a UTC time keeps its second and drops fractions", function(assert)
	assert.eq(normalizeUntil("2026-10-14T18:00:00Z"), "2026-10-14T18:00:00Z")
	assert.eq(normalizeUntil("2026-10-14T18:00:00.250Z"), "2026-10-14T18:00:00Z")
end)

test.case("a date means the start of that day in UTC", function(assert)
	assert.eq(normalizeUntil("2026-10-14"), "2026-10-14T00:00:00Z")
end)

test.case("a time with an offset or in words is refused", function(assert)
	assert.throwsWith("or a date such as 2026-10-14", function()
		normalizeUntil("2026-10-14T18:00:00-07:00")
	end)
	assert.throwsWith("or a date such as 2026-10-14", function()
		normalizeUntil("tomorrow")
	end)
end)
