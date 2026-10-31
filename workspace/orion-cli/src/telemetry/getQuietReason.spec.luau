local test = require("@std/test")

local getBuild = require("@root/telemetry/getBuild")
local getQuietReason = require("@root/telemetry/getQuietReason")

local RELEASE = getBuild("e87813e")

test.case("a release build outside perf and CI may send", function(assert)
	assert.eq(RELEASE.channel, "release")
	assert.eq(getQuietReason({}, RELEASE), nil)
	assert.eq(getQuietReason({ CI = "false" }, RELEASE), nil)
end)

test.case("checkouts and builds with uncommitted changes are dev builds", function(assert)
	assert.eq(getQuietReason({}, getBuild("dev")), "a dev build")
	assert.eq(getQuietReason({}, getBuild("e87813e-dirty")), "a dev build")
end)

test.case("perf runs and CI never send", function(assert)
	assert.eq(getQuietReason({ ORION_PERF = "1" }, RELEASE), "ORION_PERF")
	assert.eq(getQuietReason({ CI = "true" }, RELEASE), "CI")
end)
