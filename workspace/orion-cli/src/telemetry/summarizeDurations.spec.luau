local test = require("@std/test")

local summarizeDurations = require("@root/telemetry/summarizeDurations")

test.case("durations summarize as their median, 95th percentile, and slowest", function(assert)
	local samples = {}

	for value = 100, 1, -1 do
		table.insert(samples, value + 0.04)
	end

	local summary = summarizeDurations(samples) :: summarizeDurations.Summary

	assert.eq(summary.count, 100)
	assert.eq(summary.p50, 50)
	assert.eq(summary.p95, 95)
	assert.eq(summary.max, 100)
	assert.eq(samples[1], 100.04)
end)

test.case("one sample is every percentile, and none is no summary", function(assert)
	local summary = summarizeDurations({ 12.34 }) :: summarizeDurations.Summary

	assert.eq(summary.p50, 12.3)
	assert.eq(summary.p95, 12.3)
	assert.eq(summary.max, 12.3)
	assert.eq(summarizeDurations({}), nil)
end)
