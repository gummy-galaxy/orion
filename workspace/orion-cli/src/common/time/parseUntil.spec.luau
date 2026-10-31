local test = require("@std/test")

local parseUntil = require("@root/common/time/parseUntil")

test.case("parseUntil keeps a UTC time as it is", function(assert)
	assert.eq(parseUntil("2026-10-12T17:00:00Z"), "2026-10-12T17:00:00Z")
	assert.eq(parseUntil("2026-10-12T17:30Z"), "2026-10-12T17:30:00Z")
end)

test.case("parseUntil converts an offset to UTC and drops fractional seconds", function(assert)
	assert.eq(parseUntil("2026-10-12T17:00:00-07:00"), "2026-10-13T00:00:00Z")
	assert.eq(parseUntil("2026-10-12T17:00:00.250+0530"), "2026-10-12T11:30:00Z")
	assert.eq(parseUntil("2026-10-12T09:00:00+01"), "2026-10-12T08:00:00Z")
end)

test.case("parseUntil reads a date alone as the start of that day, local time", function(assert)
	assert.eq(parseUntil("2026-10-12"), parseUntil("2026-10-12T00:00"))
	assert.eq(parseUntil("2028-02-29"), parseUntil("2028-02-29T00:00"))
end)

test.case("parseUntil rejects anything other than ISO 8601 dates and date-times", function(assert)
	for _, value in
		{
			"tomorrow",
			"2d",
			"2026/10/12",
			"2026-10-12x",
			"2026-02-29",
			"2026-13-01",
			"2026-10-12T25:00Z",
			"2026-10-12T17:00+5",
		}
	do
		assert.throws(function()
			parseUntil(value)
		end)
	end
end)
