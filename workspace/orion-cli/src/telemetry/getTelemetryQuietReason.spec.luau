local test = require("@std/test")

local getBuild = require("@root/getBuild")
local getTelemetryQuietReason = require("@root/telemetry/getTelemetryQuietReason")

local RELEASE = getBuild("e87813e")

test.case("a release build outside perf and CI may send", function(assert)
	assert.eq(RELEASE.channel, "release")
	assert.eq(getTelemetryQuietReason({}, RELEASE), nil)
	assert.eq(getTelemetryQuietReason({ CI = "false" }, RELEASE), nil)
end)

test.case("checkouts and builds with uncommitted changes are dev builds", function(assert)
	assert.eq(getTelemetryQuietReason({}, getBuild("dev")), "a dev build")
	assert.eq(getTelemetryQuietReason({}, getBuild("e87813e-dirty")), "a dev build")
end)

test.case("perf runs and CI never send", function(assert)
	assert.eq(getTelemetryQuietReason({ ORION_PERF = "1" }, RELEASE), "ORION_PERF")
	assert.eq(getTelemetryQuietReason({ CI = "true" }, RELEASE), "CI")
end)
